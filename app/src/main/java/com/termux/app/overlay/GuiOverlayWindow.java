package com.termux.app.overlay;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.termux.R;
import com.termux.shared.logger.Logger;

import java.io.ByteArrayInputStream;

/**
 * A floating window drawn over other apps that shows a local web page (a GUI app served by noVNC,
 * Flet, llama-server...). It has a title bar that moves the window and buttons to reload, hide
 * (the window shrinks to a bubble), go full screen and close, and a handle to resize it.
 *
 * Must only be used from the main thread.
 */
final class GuiOverlayWindow {

    interface Callback {
        /** The user closed the window, or it cannot be shown anymore. */
        void onWindowClosed(@NonNull String id);

        /** The state changed to "open" or "hidden". */
        void onWindowStateChanged(@NonNull String id, @NonNull String state);
    }

    private static final String LOG_TAG = "GuiOverlayWindow";

    private static final int MIN_WIDTH_DP = 200;
    private static final int MIN_HEIGHT_DP = 160;
    private static final int TITLE_BAR_DP = 40;
    private static final int BUBBLE_DP = 52;

    private final Context mContext;
    private final WindowManager mWindowManager;
    private final String mId;
    private final Callback mCallback;
    private final float mDensity;
    private final int mTouchSlop;

    private OverlayRootView mRoot;
    private WebView mWebView;
    private TextView mTitleView;
    private ImageButton mFullscreenButton;
    private View mBubble;
    private WindowManager.LayoutParams mWindowParams;
    private WindowManager.LayoutParams mBubbleParams;

    private boolean mRootAttached;
    private boolean mBubbleAttached;
    private boolean mFullscreen;
    private boolean mHidden;
    private boolean mDestroyed;
    private int mNormalX, mNormalY, mNormalWidth, mNormalHeight;

    GuiOverlayWindow(@NonNull Context context, @NonNull String id, @NonNull Callback callback) {
        mContext = context;
        mWindowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        mId = id;
        mCallback = callback;
        mDensity = context.getResources().getDisplayMetrics().density;
        mTouchSlop = ViewConfiguration.get(context).getScaledTouchSlop();
    }

    // ---- public API ------------------------------------------------------------------------

    /** Create and show the window. @throws RuntimeException if the permission was not granted. */
    void show(@NonNull String title, @NonNull String url, int widthDp, int heightDp, boolean fullscreen, int index) {
        buildViews(title);
        DisplayMetrics metrics = mContext.getResources().getDisplayMetrics();
        mNormalWidth = clampPx(dp(widthDp), dp(MIN_WIDTH_DP), metrics.widthPixels - dp(16));
        mNormalHeight = clampPx(dp(heightDp), dp(MIN_HEIGHT_DP), metrics.heightPixels - dp(96));
        // Cascade several windows so they do not hide each other completely.
        mNormalX = Math.max(0, (metrics.widthPixels - mNormalWidth) / 2 + dp(24) * (index % 5));
        mNormalY = Math.max(0, dp(72) + dp(24) * (index % 5));

        mWindowParams = createLayoutParams(mNormalWidth, mNormalHeight);
        mWindowParams.x = mNormalX;
        mWindowParams.y = mNormalY;
        mWindowManager.addView(mRoot, mWindowParams);
        mRootAttached = true;

        loadUrl(url);
        if (fullscreen) setFullscreen(true);
        mCallback.onWindowStateChanged(mId, "open");
    }

    void loadUrl(@NonNull String url) {
        if (mWebView == null || !GuiPopupPolicy.isAllowedUrl(url)) return;
        // The url may contain a session password in the fragment, so it is never logged.
        mWebView.loadUrl(url);
        if (mHidden) restore();
    }

    void setTitle(@NonNull String title) {
        if (mTitleView != null) mTitleView.setText(title);
    }

    void reload() {
        if (mWebView != null) mWebView.reload();
    }

    boolean isHidden() {
        return mHidden;
    }

    /** Shrink the window to a small bubble that restores it when tapped. */
    void hide() {
        if (mDestroyed || mHidden || !mRootAttached) return;
        removeView(mRoot);
        mRootAttached = false;
        showBubble();
        mHidden = true;
        mCallback.onWindowStateChanged(mId, "hidden");
    }

    void restore() {
        if (mDestroyed || !mHidden) return;
        if (mBubbleAttached) {
            removeView(mBubble);
            mBubbleAttached = false;
        }
        try {
            mWindowManager.addView(mRoot, mWindowParams);
            mRootAttached = true;
        } catch (RuntimeException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to restore the window", e);
            close();
            return;
        }
        mHidden = false;
        mCallback.onWindowStateChanged(mId, "open");
    }

    void toggleFullscreen() {
        if (mHidden) restore();
        setFullscreen(!mFullscreen);
    }

    /** Remove the window for good and release the WebView. */
    void close() {
        if (mDestroyed) return;
        mDestroyed = true;
        if (mRootAttached) removeView(mRoot);
        if (mBubbleAttached) removeView(mBubble);
        mRootAttached = mBubbleAttached = false;
        if (mWebView != null) {
            mWebView.stopLoading();
            mWebView.loadUrl("about:blank");
            ViewGroup parent = (ViewGroup) mWebView.getParent();
            if (parent != null) parent.removeView(mWebView);
            mWebView.destroy();
            mWebView = null;
        }
        mCallback.onWindowClosed(mId);
    }

    // ---- views -----------------------------------------------------------------------------

    @SuppressLint({"SetJavaScriptEnabled", "ClickableViewAccessibility"})
    private void buildViews(@NonNull String title) {
        mRoot = new OverlayRootView(mContext);
        mRoot.setOrientation(LinearLayout.VERTICAL);
        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.parseColor("#FF111111"));
        background.setCornerRadius(dp(10));
        background.setStroke(dp(1), Color.parseColor("#FF455A64"));
        mRoot.setBackground(background);
        mRoot.setClipToOutline(true);
        mRoot.setElevation(dp(8));

        // Title bar
        LinearLayout bar = new LinearLayout(mContext);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setBackgroundColor(Color.parseColor("#FF263238"));
        mTitleView = new TextView(mContext);
        mTitleView.setText(title);
        mTitleView.setTextColor(Color.WHITE);
        mTitleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        mTitleView.setSingleLine(true);
        mTitleView.setPadding(dp(12), 0, dp(4), 0);
        bar.addView(mTitleView, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f));
        installDragHandler(mTitleView);

        bar.addView(createButton(R.drawable.ic_popup_reload, R.string.popup_reload, v -> reload()));
        bar.addView(createButton(R.drawable.ic_popup_hide, R.string.popup_hide, v -> hide()));
        mFullscreenButton = createButton(R.drawable.ic_popup_fullscreen, R.string.popup_fullscreen, v -> toggleFullscreen());
        bar.addView(mFullscreenButton);
        bar.addView(createButton(R.drawable.ic_popup_close, R.string.popup_close, v -> close()));
        mRoot.addView(bar, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(TITLE_BAR_DP)));

        // Content: the web page and a resize handle on top of it
        FrameLayout content = new FrameLayout(mContext);
        mWebView = createWebView();
        content.addView(mWebView, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        ImageView resizeHandle = new ImageView(mContext);
        resizeHandle.setImageResource(R.drawable.ic_popup_resize);
        resizeHandle.setContentDescription(mContext.getString(R.string.popup_resize));
        resizeHandle.setAlpha(0.7f);
        resizeHandle.setPadding(dp(4), dp(4), dp(4), dp(4));
        installResizeHandler(resizeHandle);
        content.addView(resizeHandle, new FrameLayout.LayoutParams(dp(32), dp(32), Gravity.BOTTOM | Gravity.END));
        mRoot.addView(content, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
    }

    private ImageButton createButton(int iconRes, int descriptionRes, View.OnClickListener listener) {
        ImageButton button = new ImageButton(mContext);
        button.setImageResource(iconRes);
        button.setBackground(null);
        button.setScaleType(ImageView.ScaleType.CENTER);
        button.setContentDescription(mContext.getString(descriptionRes));
        button.setOnClickListener(listener);
        button.setLayoutParams(new LinearLayout.LayoutParams(dp(TITLE_BAR_DP), dp(TITLE_BAR_DP)));
        return button;
    }

    @SuppressLint("SetJavaScriptEnabled")
    private WebView createWebView() {
        WebView webView = new WebView(mContext);
        webView.setBackgroundColor(Color.BLACK);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setSupportZoom(false);
        settings.setBuiltInZoomControls(false);
        // Only http pages from the device itself are shown, never local files or content providers.
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setAllowFileAccessFromFileURLs(false);
        settings.setAllowUniversalAccessFromFileURLs(false);
        settings.setGeolocationEnabled(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setMediaPlaybackRequiresUserGesture(false);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) settings.setSafeBrowsingEnabled(false);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return !isAllowedNavigation(request.getUrl().toString());
            }

            @Nullable
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                // Also covers redirects and frames: a local page cannot send the window elsewhere.
                if (request.isForMainFrame() && !isAllowedNavigation(request.getUrl().toString())) {
                    return new WebResourceResponse("text/plain", "utf-8", 403, "Forbidden", null, new ByteArrayInputStream(new byte[0]));
                }
                return null;
            }

            @Override
            public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
                Logger.logWarn(LOG_TAG, "The WebView process of window \"" + mId + "\" is gone, closing it");
                mRoot.post(GuiOverlayWindow.this::close);
                return true;
            }
        });
        webView.setWebChromeClient(new WebChromeClient());
        return webView;
    }

    private static boolean isAllowedNavigation(@NonNull String url) {
        return "about:blank".equals(url) || GuiPopupPolicy.isAllowedUrl(url);
    }

    // ---- window management -----------------------------------------------------------------

    @SuppressWarnings("deprecation")
    private WindowManager.LayoutParams createLayoutParams(int width, int height) {
        int type = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE;
        // Not focusable by default so that the app below keeps its keyboard and back button; the
        // window becomes focusable while the user interacts with it (see OverlayRootView).
        int flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
            | WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH;
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(width, height, type, flags, PixelFormat.TRANSLUCENT);
        params.gravity = Gravity.TOP | Gravity.START;
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE;
        params.setTitle("termux-gui-popup:" + mId);
        return params;
    }

    private void setFocusable(boolean focusable) {
        if (!mRootAttached || mWindowParams == null) return;
        int flags = mWindowParams.flags;
        if (focusable) flags &= ~WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
        else flags |= WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
        if (flags == mWindowParams.flags) return;
        mWindowParams.flags = flags;
        updateLayout();
    }

    private void setFullscreen(boolean fullscreen) {
        if (mDestroyed || !mRootAttached || fullscreen == mFullscreen) return;
        if (fullscreen) {
            mNormalX = mWindowParams.x;
            mNormalY = mWindowParams.y;
            mNormalWidth = mWindowParams.width;
            mNormalHeight = mWindowParams.height;
            mWindowParams.x = 0;
            mWindowParams.y = 0;
            mWindowParams.width = WindowManager.LayoutParams.MATCH_PARENT;
            mWindowParams.height = WindowManager.LayoutParams.MATCH_PARENT;
        } else {
            mWindowParams.x = mNormalX;
            mWindowParams.y = mNormalY;
            mWindowParams.width = mNormalWidth;
            mWindowParams.height = mNormalHeight;
        }
        mFullscreen = fullscreen;
        mFullscreenButton.setImageResource(fullscreen ? R.drawable.ic_popup_fullscreen_exit : R.drawable.ic_popup_fullscreen);
        updateLayout();
    }

    private void updateLayout() {
        if (!mRootAttached) return;
        try {
            mWindowManager.updateViewLayout(mRoot, mWindowParams);
        } catch (RuntimeException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to update the window", e);
        }
    }

    private void removeView(@Nullable View view) {
        if (view == null) return;
        try {
            mWindowManager.removeViewImmediate(view);
        } catch (RuntimeException e) {
            // Already removed, for example because the permission was revoked.
        }
    }

    private void showBubble() {
        ImageView bubble = new ImageView(mContext);
        bubble.setImageResource(R.drawable.ic_python_environment);
        bubble.setScaleType(ImageView.ScaleType.CENTER);
        bubble.setContentDescription(mContext.getString(R.string.popup_show));
        GradientDrawable circle = new GradientDrawable();
        circle.setShape(GradientDrawable.OVAL);
        circle.setColor(Color.parseColor("#E6263238"));
        circle.setStroke(dp(2), Color.parseColor("#FF4DB6AC"));
        bubble.setBackground(circle);
        bubble.setElevation(dp(6));
        installBubbleHandler(bubble);

        mBubbleParams = createLayoutParams(dp(BUBBLE_DP), dp(BUBBLE_DP));
        // Start where the title bar was, kept inside the screen.
        DisplayMetrics metrics = mContext.getResources().getDisplayMetrics();
        mBubbleParams.x = clampPx(mWindowParams.x, 0, metrics.widthPixels - dp(BUBBLE_DP));
        mBubbleParams.y = clampPx(mWindowParams.y, 0, metrics.heightPixels - dp(BUBBLE_DP));
        // The bubble never needs the keyboard.
        mBubbleParams.flags |= WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
        try {
            mWindowManager.addView(bubble, mBubbleParams);
            mBubble = bubble;
            mBubbleAttached = true;
        } catch (RuntimeException e) {
            Logger.logStackTraceWithMessage(LOG_TAG, "Failed to show the bubble", e);
            mHidden = true;
            close();
        }
    }

    // ---- touch handling --------------------------------------------------------------------

    @SuppressLint("ClickableViewAccessibility")
    private void installDragHandler(@NonNull View handle) {
        final float[] start = new float[4];
        handle.setOnTouchListener((v, event) -> {
            if (mFullscreen || !mRootAttached) return false;
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    start[0] = event.getRawX(); start[1] = event.getRawY();
                    start[2] = mWindowParams.x; start[3] = mWindowParams.y;
                    return true;
                case MotionEvent.ACTION_MOVE:
                    DisplayMetrics metrics = mContext.getResources().getDisplayMetrics();
                    mWindowParams.x = clampPx((int) (start[2] + event.getRawX() - start[0]), -mWindowParams.width + dp(80), metrics.widthPixels - dp(80));
                    mWindowParams.y = clampPx((int) (start[3] + event.getRawY() - start[1]), 0, metrics.heightPixels - dp(TITLE_BAR_DP));
                    updateLayout();
                    return true;
                default:
                    return true;
            }
        });
    }

    @SuppressLint("ClickableViewAccessibility")
    private void installResizeHandler(@NonNull View handle) {
        final float[] start = new float[4];
        handle.setOnTouchListener((v, event) -> {
            if (mFullscreen || !mRootAttached) return false;
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    start[0] = event.getRawX(); start[1] = event.getRawY();
                    start[2] = mWindowParams.width; start[3] = mWindowParams.height;
                    return true;
                case MotionEvent.ACTION_MOVE:
                    DisplayMetrics metrics = mContext.getResources().getDisplayMetrics();
                    mWindowParams.width = clampPx((int) (start[2] + event.getRawX() - start[0]), dp(MIN_WIDTH_DP), metrics.widthPixels - mWindowParams.x);
                    mWindowParams.height = clampPx((int) (start[3] + event.getRawY() - start[1]), dp(MIN_HEIGHT_DP), metrics.heightPixels - mWindowParams.y);
                    updateLayout();
                    return true;
                default:
                    return true;
            }
        });
    }

    @SuppressLint("ClickableViewAccessibility")
    private void installBubbleHandler(@NonNull View bubble) {
        final float[] start = new float[4];
        final boolean[] dragged = new boolean[1];
        bubble.setOnTouchListener((v, event) -> {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    start[0] = event.getRawX(); start[1] = event.getRawY();
                    start[2] = mBubbleParams.x; start[3] = mBubbleParams.y;
                    dragged[0] = false;
                    return true;
                case MotionEvent.ACTION_MOVE:
                    float dx = event.getRawX() - start[0], dy = event.getRawY() - start[1];
                    if (!dragged[0] && Math.hypot(dx, dy) > mTouchSlop) dragged[0] = true;
                    if (dragged[0] && mBubbleAttached) {
                        DisplayMetrics metrics = mContext.getResources().getDisplayMetrics();
                        mBubbleParams.x = clampPx((int) (start[2] + dx), 0, metrics.widthPixels - dp(BUBBLE_DP));
                        mBubbleParams.y = clampPx((int) (start[3] + dy), 0, metrics.heightPixels - dp(BUBBLE_DP));
                        try {
                            mWindowManager.updateViewLayout(mBubble, mBubbleParams);
                        } catch (RuntimeException ignored) {
                        }
                    }
                    return true;
                case MotionEvent.ACTION_UP:
                    if (!dragged[0]) restore();
                    return true;
                default:
                    return true;
            }
        });
    }

    /** Root view that makes the window focusable only while the user is interacting with it. */
    private final class OverlayRootView extends LinearLayout {

        OverlayRootView(Context context) {
            super(context);
        }

        @Override
        public boolean dispatchTouchEvent(MotionEvent event) {
            if (event.getAction() == MotionEvent.ACTION_OUTSIDE) {
                // The user touched the app below: give back the keyboard and the back button to it.
                setFocusable(false);
                return true;
            }
            if (event.getAction() == MotionEvent.ACTION_DOWN) setFocusable(true);
            return super.dispatchTouchEvent(event);
        }

        @Override
        public boolean dispatchKeyEvent(KeyEvent event) {
            if (event.getKeyCode() == KeyEvent.KEYCODE_BACK) {
                if (event.getAction() == KeyEvent.ACTION_UP) onBackPressed();
                return true;
            }
            return super.dispatchKeyEvent(event);
        }
    }

    private void onBackPressed() {
        if (mFullscreen) setFullscreen(false);
        else if (mWebView != null && mWebView.canGoBack()) mWebView.goBack();
        else hide();
    }

    // ---- utils -----------------------------------------------------------------------------

    private int dp(int value) {
        return Math.round(value * mDensity);
    }

    private static int clampPx(int value, int min, int max) {
        return GuiPopupPolicy.clamp(value, min, max);
    }

}
