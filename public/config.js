// Configuration for Vertex AI Video Analysis App
// This app provides real-time scene analysis without alerts
window.CONFIG = {    // Vertex AI Configuration
    VERTEX_AI: {
        ENDPOINT_ID: "mg-endpoint-1751354529", // Your deployed model endpoint
        PROJECT_ID: "609216698421",         // Project number (not project ID string)
        PROJECT_ID_STRING: "falcon-deeptech-ai-stuff", // Project ID string for reference
        REGION: "europe-west1",
        
        // This will be constructed automatically from the above values
        get DEDICATED_ENDPOINT_DOMAIN() {
            return `${this.ENDPOINT_ID}.${this.REGION}-${this.PROJECT_ID}.prediction.vertexai.goog`;
        },
        
        // API endpoint constructed from the domain
        get API_ENDPOINT() {
            return `https://${this.DEDICATED_ENDPOINT_DOMAIN}/v1/projects/${this.PROJECT_ID}/locations/${this.REGION}/endpoints/${this.ENDPOINT_ID}:predict`;
        }
    },
    
    // App Configuration
    APP: {
        DEFAULT_INTERVAL: 1000, // Default analysis interval in ms
        MAX_ALERTS: 10, // Maximum number of scene descriptions to keep in memory
        DEFAULT_JPEG_QUALITY: 0.8, // Quality for canvas image capture
        
        // Model parameters for scene description
        MODEL_PARAMS: {
            max_tokens: 256,
            temperature: 0.1,
            top_p: 0.95,
            top_k: 40
        }
    },
    
    // Environment-specific settings
    ENVIRONMENT: 'production', // Can be 'development' or 'production'
    
    // Debug settings
    DEBUG: {
        ENABLED: false, // Set to true for detailed console logging
        LOG_API_RESPONSES: false,
        LOG_FRAME_ANALYSIS: false
    }
};

// Override settings for development
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    window.CONFIG.ENVIRONMENT = 'development';
    window.CONFIG.DEBUG.ENABLED = true;
    window.CONFIG.DEBUG.LOG_API_RESPONSES = true;
}

// Utility function to log debug messages
window.debugLog = function(message, data = null) {
    if (window.CONFIG.DEBUG.ENABLED) {
        console.log(`[DEBUG] ${message}`, data || '');
    }
};

// Initialize config validation
(function validateConfig() {
    const required = ['ENDPOINT_ID', 'PROJECT_ID', 'REGION'];
    const missing = required.filter(key => !window.CONFIG.VERTEX_AI[key]);
    
    if (missing.length > 0) {
        console.error('Missing required configuration:', missing);
        window.CONFIG.CONFIG_ERROR = `Missing configuration: ${missing.join(', ')}`;
    }
    
    console.log('Video Analysis App - Configuration loaded:', {
        environment: window.CONFIG.ENVIRONMENT,
        endpoint: window.CONFIG.VERTEX_AI.ENDPOINT_ID,
        region: window.CONFIG.VERTEX_AI.REGION,
        debug: window.CONFIG.DEBUG.ENABLED
    });
})();
