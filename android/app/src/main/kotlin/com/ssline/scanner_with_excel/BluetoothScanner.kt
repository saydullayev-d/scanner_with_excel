package com.ssline.scanner_with_excel

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.util.UUID

class BluetoothScanner : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    companion object {
        private const val CHANNEL = "com.ssline.scanner_with_excel/bluetooth"
        private const val REQUEST_BLUETOOTH_PERMISSIONS = 1001
    }

    private var bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var socket: BluetoothSocket? = null
    private var inputStream: InputStream? = null
    private var channel: MethodChannel? = null
    private var readThread: Thread? = null
    private var isReading = false
    private var currentDevice: BluetoothDevice? = null
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        FlutterActivityHolder.activity = binding.activity
        binding.addRequestPermissionsResultListener { requestCode, _, grantResults ->
            if (requestCode == REQUEST_BLUETOOTH_PERMISSIONS) {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                channel?.invokeMethod("onPermissionResult", granted)
                true
            } else {
                false
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        FlutterActivityHolder.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanDevices" -> scanDevices(result)
            "connectToDevice" -> {
                val address = call.argument<String>("address")
                if (address != null) connectToDevice(address, result)
                else result.error("INVALID_ARG", "Адрес устройства не указан", null)
            }
            "disconnect" -> disconnectDevice(result)
            "isConnected" -> {
                val isConnected = socket?.isConnected == true
                val deviceName = if (isConnected) currentDevice?.name else null
                result.success(mapOf("isConnected" to isConnected, "deviceName" to deviceName))
            }
            "requestBluetoothPermission" -> requestBluetoothPermission(result)
            else -> result.notImplemented()
        }
    }

    private fun scanDevices(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_ERROR", "Bluetooth выключен", null)
            return
        }

        if (!hasBluetoothPermissions()) {
            result.error("PERMISSION_ERROR", "Нет разрешения на Bluetooth", null)
            return
        }

        val devices = adapter.bondedDevices.map { "${it.name} - ${it.address}" }
        result.success(devices)
    }

    private fun connectToDevice(deviceAddress: String, result: MethodChannel.Result) {
        val device = bluetoothAdapter?.getRemoteDevice(deviceAddress)
        currentDevice = device
        Thread {
            try {
                val sppUUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
                socket = device?.createInsecureRfcommSocketToServiceRecord(sppUUID)
                bluetoothAdapter?.cancelDiscovery()
                socket?.connect()
                inputStream = socket?.inputStream
                startReading()
                FlutterActivityHolder.activity.runOnUiThread {
                    result.success("Подключено")
                }
            } catch (e: IOException) {
                FlutterActivityHolder.activity.runOnUiThread {
                    result.error("CONNECTION_ERROR", "Ошибка подключения: ${e.message}", null)
                }
                closeSocket()
            }
        }.start()
    }

    private fun startReading() {
        isReading = true
        readThread = Thread {
            val buffer = ByteArray(1024)
            try {
                while (isReading && socket?.isConnected == true) {
                    val bytesRead = inputStream?.read(buffer) ?: -1
                    if (bytesRead > 0) {
                        val data = String(buffer, 0, bytesRead)
                        FlutterActivityHolder.activity.runOnUiThread {
                            channel?.invokeMethod("onDataReceived", data)
                        }
                    }
                }
            } catch (e: IOException) {
                disconnectDevice(null)
            }
        }.apply { start() }
    }

    private fun disconnectDevice(result: MethodChannel.Result?) {
        isReading = false
        closeSocket()
        currentDevice = null
        FlutterActivityHolder.activity.runOnUiThread {
            result?.success("Отключено")
        }
    }

    private fun closeSocket() {
        try {
            inputStream?.close()
            socket?.close()
        } catch (e: IOException) {
            // Игнорируем ошибки закрытия
        }
    }

    private fun hasBluetoothPermissions(): Boolean {
        val activity = FlutterActivityHolder.activity
        return ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(activity, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestBluetoothPermission(result: MethodChannel.Result) {
        val activity = activityBinding?.activity ?: run {
            result.error("ACTIVITY_ERROR", "Активность не найдена", null)
            return
        }

        if (hasBluetoothPermissions()) {
            result.success(true)
            return
        }

        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN),
            REQUEST_BLUETOOTH_PERMISSIONS
        )
        // Результат будет отправлен через onRequestPermissionsResult
        result.success(false) // Временно возвращаем false, пока пользователь не ответит
    }
}

object FlutterActivityHolder {
    lateinit var activity: android.app.Activity
}