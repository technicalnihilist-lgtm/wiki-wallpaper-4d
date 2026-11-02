package net.wikiwallpapers.app;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import java.io.InputStream;

public class MainActivity extends Activity {

    private static final String HOST = "appassets.androidplatform.net";
    private WebView web;

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);

        Window w = getWindow();
        w.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);
        w.setStatusBarColor(0xFF0B0D12);
        w.setNavigationBarColor(0xFF0B0D12);

        web = new WebView(this);
        web.setBackgroundColor(0xFF0B0D12);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(false);
        s.setUseWideViewPort(true);
        s.setLoadWithOverviewMode(true);
        s.setSupportZoom(false);
        s.setBuiltInZoomControls(false);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        if (Build.VERSION.SDK_INT >= 26) {
            s.setSafeBrowsingEnabled(false);
        }

        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView v, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (u != null && HOST.equals(u.getHost())) {
                    String path = u.getPath();
                    if (path == null || path.equals("/")) path = "/index.html";
                    try {
                        InputStream is = getAssets().open(path.substring(1));
                        return new WebResourceResponse(mimeOf(path), "utf-8", is);
                    } catch (Exception ignored) {
                    }
                }
                return null;
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest req) {
                Uri u = req.getUrl();
                if (u != null && HOST.equals(u.getHost())) return false;
                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, u));
                } catch (Exception ignored) {
                }
                return true;
            }
        });

        setContentView(web);
        web.loadUrl("https://" + HOST + "/index.html");
    }

    private static String mimeOf(String path) {
        if (path.endsWith(".html")) return "text/html";
        if (path.endsWith(".css")) return "text/css";
        if (path.endsWith(".js")) return "application/javascript";
        if (path.endsWith(".png")) return "image/png";
        if (path.endsWith(".jpg") || path.endsWith(".jpeg")) return "image/jpeg";
        if (path.endsWith(".svg")) return "image/svg+xml";
        return "application/octet-stream";
    }

    private void exitApp() {
        super.onBackPressed();
    }

    @Override
    public void onBackPressed() {
        final String js =
            "(function(){try{" +
            "var o=document.getElementById('overlay');" +
            "if(o&&getComputedStyle(o).display!=='none'){" +
            "  if(o.className.indexOf('fs')>-1){var b=document.getElementById('fsBtn');}" +
            "  document.getElementById('tClose').click();return 'closed';}" +
            "var c=document.getElementById('credits');" +
            "if(c&&getComputedStyle(c).display!=='none'){document.getElementById('cClose').click();return 'closed';}" +
            "var p=document.getElementById('pop');" +
            "if(p&&getComputedStyle(p).display!=='none'){document.getElementById('dots').click();return 'closed';}" +
            "return 'exit';}catch(e){return 'exit';}})()";
        web.evaluateJavascript(js, value -> {
            if (value == null || !value.contains("closed")) {
                exitApp();
            }
        });
    }

    @Override
    protected void onDestroy() {
        if (web != null) web.destroy();
        super.onDestroy();
    }
}
