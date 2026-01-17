package com.example.autospend

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class QuickAddTileService : TileService() {

    override fun onClick() {
        super.onClick()
        Log.d("AutoSpendTile", "Tile Clicked")

        try {
            // 1. Create the Intent
            val intent = Intent(this, MainActivity::class.java).apply {
                action = "QUICK_ADD_EXPENSE"
                putExtra("skip_biometric", true)  // Skip biometric for quick access
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }

            // 2. Wrap it in a PendingIntent (Crucial for Android 14+)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 3. Launch using the PendingIntent
            if (Build.VERSION.SDK_INT >= 34) {
                // For Android 14 and above
                startActivityAndCollapse(pendingIntent)
            } else {
                // For older versions
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }

        } catch (e: Exception) {
            Log.e("AutoSpendTile", "Error launching activity", e)
            Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        qsTile.state = android.service.quicksettings.Tile.STATE_ACTIVE
        qsTile.updateTile()
    }
}
