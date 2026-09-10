package com.tandd.app;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.webkit.*;

public class MainActivity extends Activity {
    private WebView web;
    private ValueCallback<Uri[]> fileCallback;
    private static final int FILE_REQUEST = 42;

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        web = new WebView(this);
        web.setBackgroundColor(Color.rgb(10,5,6));
        web.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request){
                Uri u=request.getUrl();
                if ("tandd".equalsIgnoreCase(u.getScheme())) { handleDeepLink(u); return true; }
                if ("http".equalsIgnoreCase(u.getScheme()) || "https".equalsIgnoreCase(u.getScheme())) {
                    try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch(Exception ignored) {}
                    return true;
                }
                return false;
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, String url){
                if(url.startsWith("tandd://")){ handleDeepLink(Uri.parse(url)); return true; }
                if(url.startsWith("http://") || url.startsWith("https://")){
                    try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); } catch(Exception ignored) {}
                    return true;
                }
                return false;
            }
        });
        web.setWebChromeClient(new WebChromeClient(){
            @Override public boolean onShowFileChooser(WebView v, ValueCallback<Uri[]> cb, FileChooserParams params){
                if(fileCallback!=null) fileCallback.onReceiveValue(null);
                fileCallback=cb;
                try { startActivityForResult(params.createIntent(), FILE_REQUEST); } catch(Exception e){ fileCallback=null; cb.onReceiveValue(null); }
                return true;
            }
        });
        WebSettings s=web.getSettings(); s.setJavaScriptEnabled(true); s.setDomStorageEnabled(true); s.setDatabaseEnabled(true); s.setMediaPlaybackRequiresUserGesture(false); s.setAllowFileAccess(true); s.setAllowContentAccess(true); s.setBuiltInZoomControls(false); s.setDisplayZoomControls(false);
        setContentView(web);
        web.loadUrl("file:///android_asset/index.html");
        if(savedInstanceState==null && getIntent()!=null && getIntent().getData()!=null) handleDeepLink(getIntent().getData());
    }
    private void handleDeepLink(Uri uri){
        if(uri==null) return;
        String scheme=uri.getScheme();
        if(!"tandd".equalsIgnoreCase(scheme)) return;
        if("post".equalsIgnoreCase(uri.getHost())){
            String id=uri.getPath();
            if(id!=null && id.startsWith("/")) id=id.substring(1);
            if(id!=null && !id.isEmpty()) web.loadUrl("file:///android_asset/index.html#post="+Uri.encode(id));
            return;
        }
        String fragment=uri.getEncodedFragment();
        String query=uri.getEncodedQuery();
        String suffix=""; if(fragment!=null && !fragment.isEmpty()) suffix="#"+fragment; else if(query!=null && !query.isEmpty()) suffix="?"+query;
        web.loadUrl("file:///android_asset/index.html"+suffix);
    }
    @Override protected void onNewIntent(Intent intent){ super.onNewIntent(intent); setIntent(intent); if(intent.getData()!=null && "tandd".equalsIgnoreCase(intent.getData().getScheme())) handleDeepLink(intent.getData()); }
    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data){ super.onActivityResult(requestCode,resultCode,data); if(requestCode==FILE_REQUEST && fileCallback!=null){ Uri[] r=WebChromeClient.FileChooserParams.parseResult(resultCode,data); fileCallback.onReceiveValue(r); fileCallback=null; } }
    @Override public void onBackPressed(){ if(web!=null && web.canGoBack()) web.goBack(); else super.onBackPressed(); }
}
