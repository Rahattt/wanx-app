package com.wanx.wanx.sealed

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.math.BigInteger
import java.security.AlgorithmParameters
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.KeyGenerator
import javax.crypto.Mac
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * This device's key for sealed subscriptions (`packages/wanx_sealed`).
 *
 * Android 12+: a P-256 agreement key generated inside Android Keystore;
 * the private half never leaves secure hardware. Older versions cannot do
 * ECDH in Keystore, so a software key is kept wrapped by a Keystore
 * AES-GCM key and unwrapped only in memory.
 *
 * Methods on [CHANNEL]:
 *  - `publicKey` → bytes: the uncompressed point (65 bytes)
 *  - `open` {epk, nonce, ct: bytes} → bytes: the decrypted envelope
 *  - `setSecure` {secure: bool} → blocks screenshots and screen recording
 */
class SealedKeys : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        const val CHANNEL = "com.wanx/sealed"
        private const val ALIAS = "wanx.sealed.device.v1"
        private const val WRAP_ALIAS = "wanx.sealed.wrap.v1"
        private const val PREFS = "wanx.sealed"
        private const val PREF_PRIVATE = "wrapped_private"
        private const val PREF_PUBLIC = "public"
        private val INFO = "wanx-sealed-v1".toByteArray()

        private val P256: ECParameterSpec by lazy {
            AlgorithmParameters.getInstance("EC").run {
                init(ECGenParameterSpec("secp256r1"))
                getParameterSpec(ECParameterSpec::class.java)
            }
        }

        /** ECDH → HKDF-SHA256 (empty salt, info ‖ epk ‖ own key) → AES-256-GCM, as `ecies.dart` seals it. */
        fun open(agree: (ECPublicKey) -> ByteArray, ownKey: ByteArray, epk: ByteArray, nonce: ByteArray, ct: ByteArray): ByteArray {
            val shared = agree(decodePoint(epk))
            val key = hkdf(shared, INFO + epk + ownKey)
            return Cipher.getInstance("AES/GCM/NoPadding").run {
                init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
                doFinal(ct)
            }
        }

        /** RFC 5869 with an empty salt (= HashLen zeros) and one output block. */
        private fun hkdf(ikm: ByteArray, info: ByteArray): ByteArray {
            val mac = Mac.getInstance("HmacSHA256")
            mac.init(SecretKeySpec(ByteArray(32), "HmacSHA256"))
            val prk = mac.doFinal(ikm)
            mac.init(SecretKeySpec(prk, "HmacSHA256"))
            mac.update(info)
            mac.update(1)
            return mac.doFinal()
        }

        fun encodePoint(key: ECPublicKey): ByteArray =
            byteArrayOf(4) + fixed(key.w.affineX) + fixed(key.w.affineY)

        /** Uncompressed point → key, rejecting anything not on P-256. */
        fun decodePoint(bytes: ByteArray): ECPublicKey {
            require(bytes.size == 65 && bytes[0] == 4.toByte()) { "Bad ephemeral key" }
            val x = BigInteger(1, bytes.copyOfRange(1, 33))
            val y = BigInteger(1, bytes.copyOfRange(33, 65))
            val curve = P256.curve
            val p = (curve.field as java.security.spec.ECFieldFp).p
            require(y.multiply(y).mod(p) == x.pow(3).add(curve.a.multiply(x)).add(curve.b).mod(p)) {
                "Ephemeral key is not on P-256"
            }
            return KeyFactory.getInstance("EC").generatePublic(ECPublicKeySpec(ECPoint(x, y), P256)) as ECPublicKey
        }

        private fun fixed(n: BigInteger): ByteArray {
            val raw = n.toByteArray()
            return when {
                raw.size == 32 -> raw
                raw.size > 32 -> raw.copyOfRange(raw.size - 32, raw.size)
                else -> ByteArray(32 - raw.size) + raw
            }
        }
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "publicKey" -> run(result) { key().publicKey }
            "open" -> {
                val epk = call.argument<ByteArray>("epk")
                val nonce = call.argument<ByteArray>("nonce")
                val ct = call.argument<ByteArray>("ct")
                if (epk == null || nonce == null || ct == null) {
                    return result.error("BAD_ARGS", "epk, nonce and ct are required", null)
                }
                run(result) {
                    val key = key()
                    open(key::agree, key.publicKey, epk, nonce, ct)
                }
            }
            "setSecure" -> {
                val window = activity?.window ?: return result.success(null)
                if (call.argument<Boolean>("secure") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** Keystore work off the main thread; key generation can take a moment. */
    private fun run(result: MethodChannel.Result, work: () -> ByteArray) {
        worker.execute {
            try {
                val bytes = work()
                main.post { result.success(bytes) }
            } catch (e: Exception) {
                main.post { result.error("SEALED", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    private class DeviceKey(val publicKey: ByteArray, private val private: PrivateKey, private val provider: String?) {
        fun agree(peer: ECPublicKey): ByteArray {
            val agreement = if (provider == null) KeyAgreement.getInstance("ECDH") else KeyAgreement.getInstance("ECDH", provider)
            agreement.init(private)
            agreement.doPhase(peer, true)
            return agreement.generateSecret()
        }
    }

    private var cached: DeviceKey? = null

    /** Only touched from [worker], so no locking. */
    private fun key(): DeviceKey {
        cached?.let { return it }
        val key = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) keystoreKey() else wrappedKey()
        cached = key
        return key
    }

    private fun keyStore() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    private fun keystoreKey(): DeviceKey {
        val store = keyStore()
        if (!store.containsAlias(ALIAS)) {
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore").run {
                initialize(
                    KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_AGREE_KEY)
                        .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                        .build(),
                )
                generateKeyPair()
            }
        }
        val private = store.getKey(ALIAS, null) as PrivateKey
        val public = store.getCertificate(ALIAS).publicKey as ECPublicKey
        return DeviceKey(encodePoint(public), private, "AndroidKeyStore")
    }

    private fun wrappedKey(): DeviceKey {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val wrap = wrapKey()
        val stored = prefs.getString(PREF_PRIVATE, null)
        val storedPublic = prefs.getString(PREF_PUBLIC, null)
        val factory = KeyFactory.getInstance("EC")
        if (stored != null && storedPublic != null) {
            try {
                val blob = Base64.decode(stored, Base64.NO_WRAP)
                val pkcs8 = Cipher.getInstance("AES/GCM/NoPadding").run {
                    init(Cipher.DECRYPT_MODE, wrap, GCMParameterSpec(128, blob.copyOfRange(0, 12)))
                    doFinal(blob.copyOfRange(12, blob.size))
                }
                val public = factory.generatePublic(X509EncodedKeySpec(Base64.decode(storedPublic, Base64.NO_WRAP))) as ECPublicKey
                return DeviceKey(encodePoint(public), factory.generatePrivate(PKCS8EncodedKeySpec(pkcs8)), null)
            } catch (e: Exception) {
                // Restored from a backup onto a device whose Keystore never
                // had the wrapping key: start over with a new device key.
            }
        }
        val pair = KeyPairGenerator.getInstance("EC").run {
            initialize(ECGenParameterSpec("secp256r1"))
            generateKeyPair()
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, wrap) }
        val blob = cipher.iv + cipher.doFinal(pair.private.encoded)
        prefs.edit()
            .putString(PREF_PRIVATE, Base64.encodeToString(blob, Base64.NO_WRAP))
            .putString(PREF_PUBLIC, Base64.encodeToString(pair.public.encoded, Base64.NO_WRAP))
            .commit()
        return DeviceKey(encodePoint(pair.public as ECPublicKey), pair.private, null)
    }

    private fun wrapKey(): SecretKey {
        val store = keyStore()
        (store.getKey(WRAP_ALIAS, null) as SecretKey?)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(
                KeyGenParameterSpec.Builder(WRAP_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
            generateKey()
        }
    }
}
