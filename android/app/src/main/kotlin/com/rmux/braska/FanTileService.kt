package com.rmux.braska

import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import androidx.annotation.RequiresApi
import java.net.HttpURLConnection
import java.net.URL
import java.io.OutputStreamWriter
import kotlin.concurrent.thread

@RequiresApi(Build.VERSION_CODES.N)
class FanTileService : TileService() {
    
    private fun getPrefs(): SharedPreferences {
        return getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTileUI()
    }

    override fun onClick() {
        super.onClick()
        val prefs = getPrefs()
        
        var fan = prefs.getLong("flutter.ps4_tile_fan_val", 70L).toInt()
        fan += 5
        if (fan > 80) fan = -10
        prefs.edit().putLong("flutter.ps4_tile_fan_val", fan.toLong()).apply()
        
        updateTileUI()

        thread {
            val urlStr = prefs.getString("flutter.ps4_addr", "") ?: ""
            val token = prefs.getString("flutter.ps4_token", "") ?: ""
            
            if (urlStr.isEmpty()) return@thread
            
            try {
                val fullUrl = if (urlStr.startsWith("http")) "$urlStr/api/fan/threshold" else "http://$urlStr/api/fan/threshold"
                val url = URL(fullUrl)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                if (token.isNotEmpty()) {
                    conn.setRequestProperty("Authorization", "Bearer $token")
                }
                conn.doOutput = true
                val json = """{"threshold": $fan}"""
                OutputStreamWriter(conn.outputStream).use { it.write(json) }
                
                val responseCode = conn.responseCode
                println("FanTileService: POST returned $responseCode")
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun updateTileUI() {
        val tile = qsTile ?: return
        val prefs = getPrefs()
        val urlStr = prefs.getString("flutter.ps4_addr", "") ?: ""
        
        if (urlStr.isEmpty()) {
            tile.label = "PS4 Fan"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                tile.subtitle = "App Setup Rqd"
            }
            tile.state = Tile.STATE_UNAVAILABLE
            tile.updateTile()
            return
        }

        val fan = prefs.getLong("flutter.ps4_tile_fan_val", 70L).toInt()
        tile.label = "Fan: $fan°C"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = "Tap to cycle"
        }
        tile.state = Tile.STATE_ACTIVE
        tile.updateTile()
    }
}
