package com.bitmark.autonomy_flutter

import android.content.Context
import timber.log.Timber
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.FileReader
import java.io.FileWriter

class FileLogger(context: Context) {

    companion object {
        private var INSTANCE: FileLogger? = null
        val MAX_FILE_SIZE = 1024 * 1024 // Maximum file size in bytes (e.g., 1 MB)


        fun init(context: Context) = INSTANCE ?: FileLogger(context).also { INSTANCE = it }

        fun log(tag: String, message: String) {
            INSTANCE?.log(tag, message)
        }

        fun getLogContent(): String {
            return INSTANCE?.readLogContent() ?: ""
        }
    }

    private val _fileLogger: File

    fun getFile(): File {
        return _fileLogger
    }

    init {
        _fileLogger = File(context.filesDir, "app.log")
        if (!_fileLogger.exists()) {
            _fileLogger.createNewFile()
        }
    }

    private fun readLogContent(): String {
        val content = StringBuilder()
        BufferedReader(FileReader(_fileLogger)).use { reader ->
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                content.append(line).append("\n")
            }
        }
        return content.toString()
    }

    private fun checkAndRotateLog() {
        if (_fileLogger.length() <= MAX_FILE_SIZE) return

        val tempFile = File(_fileLogger.parent, "app.log.temp")
        val linesToKeep = kotlin.collections.ArrayDeque<String>()
        var currentSize = 0L

        // Read the log file line by line and keep only the lines that fit within the size limit
        BufferedReader(FileReader(_fileLogger)).use { reader ->
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val lineSize = line!!.toByteArray().size.toLong()

                // Add the line and update the size
                linesToKeep.add(line!!)
                currentSize += lineSize

                // Remove oldest lines if size exceeds MAX_FILE_SIZE
                while (currentSize > MAX_FILE_SIZE && linesToKeep.isNotEmpty()) {
                    val removedLine = linesToKeep.removeFirst()
                    currentSize -= removedLine.toByteArray().size
                }
            }
        }

        // Write the retained lines to the temporary file
        FileWriter(tempFile).use { writer ->
            linesToKeep.forEach { writer.write("$it\n") }
        }

        // Replace the old log file with the new one
        if (_fileLogger.delete()) {
            tempFile.renameTo(_fileLogger)
        }
    }

    private fun log(tag: String, message: String) {
        if (_fileLogger.canWrite()) {
            checkAndRotateLog()

            val now =
                java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss", java.util.Locale.getDefault())
                    .format(java.util.Date())
            Timber.tag(tag).d(message)
            val trimmedMessage =
                if (message.length > 1000) message.take(1000) + "...[truncated]" else message
            FileOutputStream(_fileLogger, true).apply {
                write("[$now] $tag: $trimmedMessage\n".encodeToByteArray())
                flush()
                close()
            }
        }
    }
}