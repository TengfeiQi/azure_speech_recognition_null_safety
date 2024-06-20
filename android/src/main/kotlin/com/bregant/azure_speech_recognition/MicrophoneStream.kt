package com.bregant.azure_speech_recognition

import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.util.Log;

import java.io.File
import java.io.FileOutputStream
import java.io.IOException

import com.microsoft.cognitiveservices.speech.audio.PullAudioInputStreamCallback;
import com.microsoft.cognitiveservices.speech.audio.AudioStreamFormat;



class MicrophoneStream(
    var SAMPLE_RATE : Int = 16000, 
    var thisFormat : AudioStreamFormat = AudioStreamFormat.getWaveFormatPCM(16000.toLong(), 16.toShort(), 1.toShort()),
    var recorder : AudioRecord? = null
    ) : PullAudioInputStreamCallback() {
//(sRATE:Int,sFormat:AudioStreamFormat,sRecorder:AudioRecord)
    //private val  SAMPLE_RATE : Int = 16000;
    //private var thisFormat : AudioStreamFormat;
    //private var recorder : AudioRecord? = null;

    private lateinit var outputFile: String

    init {
        //thisFormat = AudioStreamFormat.getWaveFormatPCM(SAMPLE_RATE.toLong(), 16.toShort(), 1.toShort());
        initMic();
    }

    fun getFormat() : AudioStreamFormat {
        return this.thisFormat;
    }

    //@Override
    override fun read(bytes : ByteArray) :Int {
        var ret : Int = recorder!!.read(bytes, 0, bytes.size);
        // Write the audio data to the output file 
        // writeToFile(bytes); // add by Tengfei
        return ret;
    }

    
    override fun close() {
        this.recorder!!.release();
        this.recorder = null;
    }

    fun initMic() {
        // Note: currently, the Speech SDK support 16 kHz sample rate, 16 bit samples, mono (single-channel) only.
        var af : AudioFormat = AudioFormat.Builder()
                .setSampleRate(SAMPLE_RATE)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                .build();
        this.recorder = AudioRecord.Builder()
                .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                .setAudioFormat(af)
                .build();

        this.recorder!!.startRecording();
    }

    // Method to set the output file path
    // Add by Tengfei
    fun setOutputFile(outputFile: String) {
        this.outputFile = outputFile
    }

    // Method to write audio data to the output file
    // Add by Tengfei
    private fun writeToFile(bytes: ByteArray) {
        try {
            val fileOutputStream = FileOutputStream(outputFile, true) // append mode
            fileOutputStream.write(bytes)
            fileOutputStream.close()
        } catch (e: IOException) {
            Log.e("MicrophoneStream", "Error writing audio to file: ${e.message}")
        }
    }
}