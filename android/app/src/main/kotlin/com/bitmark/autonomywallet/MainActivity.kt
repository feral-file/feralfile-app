/* SPDX-License-Identifier: BSD-2-Clause-Patent
 * Copyright © 2022 Bitmark. All rights reserved.
 * Use of this source code is governed by the BSD-2-Clause Plus Patent License
 * that can be found in the LICENSE file.
 */

package com.bitmark.autonomywallet

import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.enableEdgeToEdge
import com.bitmark.autonomy_flutter.FileLogger
import com.bitmark.autonomy_flutter.jsonKT
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.BlockstoreClient
import com.google.android.gms.auth.blockstore.BlockstoreClient.DEFAULT_BYTES_DATA_KEY
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable


class MainActivity : FlutterFragmentActivity() {
    companion object {
        private val systemChanel = "com.feralfile.wallet"
        private lateinit var client: BlockstoreClient
    }

    private val CHANNEL = "com.feralfile.wallet/log"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FileLogger.init(applicationContext)
        // verity signing certificate


        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            window.setHideOverlayWindows(true)
        }

        val systemChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, systemChanel)
        systemChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "exportMnemonicForAllPersonaUUIDs" -> exportMnemonicForAllPersonaUUIDs(result)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getLogContent" -> {
                    try {
                        val logContent = FileLogger.getLogContent()
                        result.success(logContent)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Could not get log content", e.toString())
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        client = Blockstore.getClient(this)
    }

    private fun exportMnemonicForAllPersonaUUIDs(result: MethodChannel.Result) {
        val retrieveBytesRequestBuilder = RetrieveBytesRequest.Builder()
            .setRetrieveAll(true)

        client.retrieveBytes(retrieveBytesRequestBuilder.build())
            .addOnSuccessListener { bytes ->
                try {
                    val dataMap = bytes.blockstoreDataMap
                    val defaultBytesData = dataMap[DEFAULT_BYTES_DATA_KEY]
                    val data = jsonKT.decodeFromString(
                        BackupData.serializer(),
                        defaultBytesData?.bytes?.toString(Charsets.UTF_8) ?: ""
                    )

                    val mnemonicsMap =
                        mutableMapOf<String, List<String>>() // Map<String, List<String>>

                    data.accounts.forEach { account ->
                        val uuid = account.uuid
                        val mnemonic = account.mnemonic.split(" ")
                        val passphrase = account.passphrase ?: ""

                        mnemonicsMap[uuid] = listOf(passphrase) + mnemonic
                    }
                    result.success(mnemonicsMap)
                } catch (e: Exception) {
                    e.printStackTrace()
                    // No accounts found
                    result.error("exportMnemonicForAllPersonaUUIDs error", e.message, e)
                }
            }
            .addOnFailureListener { e ->
                Log.e("MainActivity", e.message ?: "Blockstore retrieval error")
                result.error(
                    "exportMnemonicForAllPersonaUUIDs Blockstore retrieval error",
                    e.message,
                    e
                )
            }
    }
}

@Serializable
data class BackupData(
    @SerialName("accounts")
    val accounts: List<BackupAccount>
)

@kotlinx.serialization.Serializable
data class BackupAccount(
    @SerialName("uuid")
    val uuid: String,
    @SerialName("mnemonic")
    val mnemonic: String,
    @SerialName("passphrase")
    val passphrase: String? = null,
    @SerialName("name")
    val name: String,
)
