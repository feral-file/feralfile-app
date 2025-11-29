package com.bitmark.autonomy_flutter

import android.app.Activity
import android.net.Uri
import android.os.Bundle
import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.*
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File
import java.io.IOException
import java.util.Base64

class EmergencyLog : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val logger = FileLogger.init(applicationContext)
        val data: Uri? = intent.data
        val token: String? = data?.lastPathSegment

        if (token != null) {
            uploadLogFile(logger.getFile(), token)
        }
    }

    private fun uploadLogFile(file: File, token: String) {
        val client = OkHttpClient()

        val requestBody = buildRequestBody(file)

        // Build the request
        val url = if (BuildConfig.FLAVOR.contains("inhouse")) {
            "https://support.test.autonomy.io/v1/issues/"
        } else {
            "https://support.autonomy.io/v1/issues/"
        }

        val request = Request.Builder()
            .url(url)
            .post(requestBody)
            .header("Authorization", "Emergency $token")
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                e.printStackTrace()
                // Handle failure
            }

            override fun onResponse(call: Call, response: Response) {
                if (response.isSuccessful) {
                    // Handle successful upload
                    println("Log file uploaded successfully")
                } else {
                    // Handle unsuccessful upload
                    println("Failed to upload log file")
                }
            }
        })
    }

    private fun buildRequestBody(file: File): RequestBody {
        // Read the log file content as base64
        val base64Content = Base64.getEncoder().encodeToString(file.readBytes())

        // Construct the attachments array with base64 data and file name
        val attachments = listOf(
            mapOf("data" to base64Content, "title" to file.name, "path" to "", "contentType" to "")
        )

        // Construct the request body as JSON
        val requestBodyMap = mapOf(
            "attachments" to attachments,
            "title" to "Emergency log",
            "message" to "message",
            "tags" to listOf("emergency", "android"),
            "announcement_context_id" to ""
        )

        val gson = Gson()
        val json = gson.toJson(requestBodyMap)

        return json.toRequestBody("application/json".toMediaTypeOrNull())
    }

}