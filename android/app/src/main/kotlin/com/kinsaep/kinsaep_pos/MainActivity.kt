package com.kinsaep.kinsaep_pos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private var scannerReceiverRegistered = false

    private val scannerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            val code = when (action) {
                SUNMI_ACTION -> intent.getStringExtra(SUNMI_DATA_KEY)
                ZEBRA_ACTION -> {
                    intent.getStringExtra(ZEBRA_DATA_KEY)
                        ?: intent.getStringExtra(SUNMI_DATA_KEY)
                }
                else -> null
            }

            if (!code.isNullOrBlank()) {
                runOnUiThread {
                    eventSink?.success(
                        mapOf(
                            "code" to code,
                            "source" to action,
                        ),
                    )
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCANNER_EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerScannerReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterScannerReceiver()
                }
            },
        )
    }

    override fun onResume() {
        super.onResume()
        if (eventSink != null) {
            registerScannerReceiver()
        }
    }

    override fun onPause() {
        unregisterScannerReceiver()
        super.onPause()
    }

    private fun registerScannerReceiver() {
        if (scannerReceiverRegistered) {
            return
        }

        val filter = IntentFilter().apply {
            addAction(SUNMI_ACTION)
            addAction(ZEBRA_ACTION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(scannerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(scannerReceiver, filter)
        }
        scannerReceiverRegistered = true
    }

    private fun unregisterScannerReceiver() {
        if (!scannerReceiverRegistered) {
            return
        }
        unregisterReceiver(scannerReceiver)
        scannerReceiverRegistered = false
    }

    companion object {
        private const val SCANNER_EVENT_CHANNEL = "com.kinsaep.kinsaep_pos/scanner_events"
        private const val SUNMI_ACTION = "com.sunmi.scanner.ACTION_DATA_CODE_RECEIVED"
        private const val SUNMI_DATA_KEY = "data"

        // Configure Zebra DataWedge intent output to this action:
        // Intent action: com.kinsaep.kinsaep_pos.SCAN
        // Intent delivery: Broadcast intent
        private const val ZEBRA_ACTION = "com.kinsaep.kinsaep_pos.SCAN"
        private const val ZEBRA_DATA_KEY = "com.symbol.datawedge.data_string"
    }
}
