// Main application JavaScript for Vertex AI Video Analysis
(function() {
    'use strict';

    // Check if config is loaded
    if (!window.CONFIG) {
        console.error('Configuration not loaded! Make sure config.js is included before app.js');
        return;
    }

    // Show configuration error if any
    if (window.CONFIG.CONFIG_ERROR) {
        alert('Configuration Error: ' + window.CONFIG.CONFIG_ERROR);
        return;
    }

    // --- DOM Elements ---
    const video = document.getElementById('webcam');
    const canvas = document.getElementById('canvas');
    const startButton = document.getElementById('startButton');
    const stopButton = document.getElementById('stopButton');
    const alertConditionInput = document.getElementById('alert-condition');
    const accessTokenInput = document.getElementById('accessToken');
    const intervalSelect = document.getElementById('intervalSelect');
    const dynamicAlertCheck = document.getElementById('dynamicAlertCheck');
    const alertsContainer = document.getElementById('alerts-container');
    const cameraPrompt = document.getElementById('camera-prompt');
    const loader = document.getElementById('loader');
    const statusText = document.getElementById('status-text');
    const sceneDescription = document.getElementById('scene-description');

    // --- State ---
    let stream;
    let analysisTimeoutId;
    let isAnalyzing = false;

    // Set default interval from config
    intervalSelect.value = window.CONFIG.APP.DEFAULT_INTERVAL.toString();

    // --- Core Functions ---

    /**
     * Initializes the webcam stream.
     */
    async function initWebcam() {
        try {
            stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
            video.srcObject = stream;
            cameraPrompt.classList.add('hidden');
            video.addEventListener('loadedmetadata', () => {
                canvas.width = video.videoWidth;
                canvas.height = video.videoHeight;
                window.debugLog('Webcam initialized', { width: canvas.width, height: canvas.height });
            });
        } catch (err) {
            console.error("Error accessing webcam:", err);
            addAlert('error', 'Could not access webcam. Please check permissions and try again.');
            cameraPrompt.textContent = 'Camera access denied.';
        }
    }

    /**
     * Starts the video analysis loop.
     */
    function startAnalysis() {
        const alertCondition = alertConditionInput.value.trim();
        const accessToken = accessTokenInput.value.trim();

        if (!alertCondition || !accessToken) {
            addAlert('error', 'Please fill in the "Alert for" and "Access Token" fields.');
            return;
        }
        if (!stream) {
             addAlert('error', 'Webcam is not available. Cannot start analysis.');
             return;
        }

        isAnalyzing = true;
        updateUIState();
        addAlert('info', `Analysis started with ${intervalSelect.value}ms interval.`);
        window.debugLog('Analysis started', { 
            condition: alertCondition, 
            interval: intervalSelect.value,
            endpoint: window.CONFIG.VERTEX_AI.API_ENDPOINT
        });
        analyzeFrame(); // Start the first frame analysis immediately.
    }

    /**
     * Stops the video analysis loop.
     */
    function stopAnalysis() {
        isAnalyzing = false;
        clearTimeout(analysisTimeoutId); // Stop the pending next frame
        updateUIState();
        addAlert('info', 'Analysis stopped.');
        sceneDescription.textContent = 'Awaiting analysis...';
        window.debugLog('Analysis stopped');
    }

    /**
     * Gets the current alert condition (either static or dynamic)
     */
    function getCurrentAlertCondition() {
        return alertConditionInput.value.trim();
    }

    /**
     * Improved boolean detection for YES/NO responses
     */
    function detectAlertResponse(text) {
        const normalizedText = text.toLowerCase().trim();
        
        // Check for various positive patterns (alert should trigger)
        const positivePatterns = [
            /\byes\b/,
            /\btrue\b/,
            /\bdetected\b/,
            /\bpresent\b/,
            /\bfound\b/,
            /\bconfirmed\b/
        ];
        
        // Check for various negative patterns (no alert)
        const negativePatterns = [
            /\bno\b/,
            /\bfalse\b/,
            /\bnot detected\b/,
            /\babsent\b/,
            /\bnot present\b/,
            /\bnot found\b/
        ];
        
        // Check each pattern
        for (const pattern of positivePatterns) {
            if (pattern.test(normalizedText)) {
                return 'yes';
            }
        }
        
        for (const pattern of negativePatterns) {
            if (pattern.test(normalizedText)) {
                return 'no';
            }
        }
        
        // If no clear result found, return null
        return null;
    }

    /**
     * Captures a frame, sends it to Vertex AI, and handles the response.
     */
    async function analyzeFrame() {
        if (!isAnalyzing) return;

        const context = canvas.getContext('2d');
        context.drawImage(video, 0, 0, canvas.width, canvas.height);
        const imageData = canvas.toDataURL('image/jpeg', window.CONFIG.APP.DEFAULT_JPEG_QUALITY).split(',')[1];
        
        // Get current alert condition (allows for dynamic updates)
        const currentAlertCondition = getCurrentAlertCondition();
        
        // Improved prompt for better scene description and accurate condition detection
        const textPrompt = `Analyze this image and provide a detailed response in the exact format below.

SCENE: [Describe what you see - people, objects, clothing, safety equipment, activities, environment details]
CONDITION: ${currentAlertCondition}
ALERT: [YES or NO]

Instructions:
1. SCENE: Always describe what you observe in detail, focusing on people, their clothing, safety equipment, and activities
2. CONDITION: This is what we're monitoring for
3. ALERT: Answer YES if the condition is currently happening/present in the image, NO if it is not

Examples for clarity:
- If condition is "person not wearing glasses" → ALERT: YES when person has NO glasses, NO when person HAS glasses
- If condition is "person wearing helmet" → ALERT: YES when person HAS helmet, NO when person has NO helmet  
- If condition is "unsafe behavior" → ALERT: YES when unsafe behavior IS present, NO when behavior is safe

Be very careful with negations. If the condition contains "not" then YES means the negative thing is happening.

Format your response exactly as:
SCENE: [your detailed description]
CONDITION: ${currentAlertCondition}
ALERT: [YES or NO]`;

        const payload = {
            "instances": [
                {
                    "@requestFormat": "chatCompletions",
                    "messages": [
                        {
                            "role": "system",
                            "content": "You are a visual safety monitoring AI. Always respond in the exact format requested with SCENE:, CONDITION:, and ALERT: lines. Be precise with your observations and alert decisions."
                        },
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "image_url",
                                    "image_url": { "url": `data:image/jpeg;base64,${imageData}` }
                                },
                                {
                                    "type": "text", "text": textPrompt
                                }
                            ]
                        }
                    ],
                    ...window.CONFIG.APP.MODEL_PARAMS
                }
            ]
        };

        setLoading(true);

        try {
            window.debugLog('Sending API request', window.CONFIG.DEBUG.LOG_FRAME_ANALYSIS ? { 
                endpoint: window.CONFIG.VERTEX_AI.API_ENDPOINT,
                condition: currentAlertCondition 
            } : null);

            const response = await fetch(window.CONFIG.VERTEX_AI.API_ENDPOINT, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${accessTokenInput.value}`
                },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const errorText = await response.text();
                let errorMessage = errorText;
                try {
                    const errorJson = JSON.parse(errorText);
                    errorMessage = errorJson?.error?.message || errorMessage;
                } catch (e) {
                     console.warn("Server error response was not in JSON format.");
                }
                throw new Error(`API Error (${response.status}): ${errorMessage}`);
            }

            const data = await response.json();
            if (window.CONFIG.DEBUG.LOG_API_RESPONSES) {
                window.debugLog('API Response received', data);
            }
            processApiResponse(data, currentAlertCondition);

        } catch (err) {
            console.error('Error calling Vertex AI:', err);
            addAlert('error', `Failed to analyze frame: ${err.message}`);
            stopAnalysis(); // Stop on error
        } finally {
            setLoading(false);
            // Queue the next analysis frame if still active.
            if (isAnalyzing) {
                const intervalMs = parseInt(intervalSelect.value, 10);
                analysisTimeoutId = setTimeout(analyzeFrame, intervalMs);
            }
        }
    }

    /**
     * Processes the prediction from the Vertex AI API.
     */
    function processApiResponse(data, alertCondition) {
        const predictionText = data?.predictions?.[0]?.content || data?.predictions?.choices?.[0]?.message?.content;

        // Check if the response is a valid, non-empty string.
        if (typeof predictionText !== 'string' || predictionText.trim() === '') {
            addAlert('error', 'Model returned an empty or invalid response.');
            sceneDescription.textContent = 'Model returned an empty response.';
            return;
        }

        try {
            const trimmedText = predictionText.trim();
            window.debugLog("Raw model response", trimmedText);
            
            let description = '';
            let alertResult = null;
            
            // Split into lines for parsing
            const lines = trimmedText.split('\n').map(line => line.trim()).filter(Boolean);
            window.debugLog("Parsed lines", lines);
            
            // Parse the response format: SCENE:, CONDITION:, ALERT:
            for (const line of lines) {
                if (line.startsWith('SCENE:')) {
                    description = line.substring('SCENE:'.length).trim();
                    window.debugLog("Found SCENE", description);
                } else if (line.startsWith('ALERT:')) {
                    const alertLine = line.substring('ALERT:'.length).trim().toLowerCase();
                    window.debugLog("Found ALERT line", alertLine);
                    
                    // Check for YES/NO or TRUE/FALSE
                    if (alertLine.includes('yes') || alertLine.includes('true')) {
                        alertResult = 'yes';
                    } else if (alertLine.includes('no') || alertLine.includes('false')) {
                        alertResult = 'no';
                    }
                    window.debugLog("Extracted alert result", alertResult);
                }
            }
            
            // Fallback parsing if main format not found
            if (!description) {
                // Try to find a description in any line that looks descriptive
                for (const line of lines) {
                    const cleanLine = line.replace(/^(SCENE:|DESCRIPTION:|CONDITION:|ALERT:)/i, '').trim();
                    if (cleanLine.length > 15 && !/\b(yes|no|true|false)\b/i.test(cleanLine)) {
                        description = cleanLine;
                        window.debugLog("Fallback description found", description);
                        break;
                    }
                }
                
                // If still no description, use the entire text without alert keywords
                if (!description) {
                    const textWithoutAlerts = trimmedText.replace(/\b(alert|yes|no|true|false|condition)[\s:]*\w*/gi, '').trim();
                    if (textWithoutAlerts.length > 10) {
                        description = textWithoutAlerts.substring(0, 100) + (textWithoutAlerts.length > 100 ? '...' : '');
                    }
                }
            }
            
            // Fallback alert detection
            if (!alertResult) {
                const lowerText = trimmedText.toLowerCase();
                if (lowerText.includes('yes') || lowerText.includes('true') || lowerText.includes('detected') || lowerText.includes('present')) {
                    alertResult = 'yes';
                } else if (lowerText.includes('no') || lowerText.includes('false') || lowerText.includes('not detected') || lowerText.includes('absent')) {
                    alertResult = 'no';
                }
                window.debugLog("Fallback alert result", alertResult);
            }
            
            // Ensure we have at least some description
            const finalDescription = description || 'Scene being analyzed...';
            window.debugLog("Final description", finalDescription);
            
            // Update scene description in the UI
            if (finalDescription !== 'Scene being analyzed...') {
                sceneDescription.textContent = finalDescription;
                sceneDescription.classList.remove('text-gray-400');
                sceneDescription.classList.add('text-cyan-300');
            } else {
                sceneDescription.textContent = finalDescription;
                sceneDescription.classList.remove('text-cyan-300');
                sceneDescription.classList.add('text-gray-400');
            }
            
            // Handle alert logic
            if (alertResult === 'yes') {
                const alertMessage = `🚨 DETECTED: ${alertCondition}`;
                addAlert('warning', alertMessage);
                window.debugLog("ALERT TRIGGERED", { condition: alertCondition, description: finalDescription });
            } else if (alertResult === 'no') {
                window.debugLog("No alert - condition not detected", { condition: alertCondition, description: finalDescription });
                // Occasionally show monitoring status
                if (Math.random() < 0.03) { // Show less frequently (3%)
                    addAlert('info', `✓ Monitoring: ${alertCondition.substring(0, 40)}${alertCondition.length > 40 ? '...' : ''}`);
                }
            } else {
                window.debugLog("Could not determine alert result from response", trimmedText);
                addAlert('error', 'Could not parse model response - check console for details');
            }

        } catch (e) {
            console.error("Error processing model response:", e);
            addAlert('error', `Processing error: ${e.message}`);
            sceneDescription.textContent = 'Error processing response.';
        }
    }

    // --- UI Helper Functions ---

    /**
     * Updates buttons and status text based on the analysis state.
     */
    function updateUIState() {
        startButton.disabled = isAnalyzing;
        stopButton.disabled = !isAnalyzing;
        intervalSelect.disabled = isAnalyzing;
        
        // Only disable alert condition if dynamic updates are not allowed
        if (!dynamicAlertCheck.checked) {
            alertConditionInput.disabled = isAnalyzing;
        }
        
        accessTokenInput.disabled = isAnalyzing;

        if (isAnalyzing) {
            statusText.textContent = 'Running...';
            statusText.classList.remove('text-gray-400');
            statusText.classList.add('text-green-400');
        } else {
            statusText.textContent = 'Idle';
            statusText.classList.remove('text-green-400');
            statusText.classList.add('text-gray-400');
        }
    }

    /**
     * Shows or hides the loading spinner.
     * @param {boolean} isLoading
     */
    function setLoading(isLoading) {
        if (isLoading) {
            loader.classList.remove('hidden');
        } else {
            loader.classList.add('hidden');
        }
    }

    /**
     * Adds a formatted alert message to the UI.
     * @param {'info'|'warning'|'error'} type The type of alert.
     * @param {string} message The message to display.
     */
    function addAlert(type, message) {
        const timestamp = new Date().toLocaleTimeString();
        let bgColor, textColor, icon;

        switch(type) {
            case 'warning': // This is now the main alert, styled in red
                bgColor = 'bg-red-600/30';
                textColor = 'text-red-300';
                icon = '🚨';
                break;
            case 'error': // For system/API errors
                bgColor = 'bg-yellow-500/20';
                textColor = 'text-yellow-400';
                icon = '❌';
                break;
            default: // info
                bgColor = 'bg-blue-500/20';
                textColor = 'text-blue-300';
                icon = 'ℹ️';
        }
        
        const alertEl = document.createElement('div');
        alertEl.className = `p-3 rounded-lg ${bgColor} ${textColor} text-sm flex items-start gap-3`;
        alertEl.innerHTML = `
            <span class="mt-1 text-lg">${icon}</span>
            <div class="flex-1">
                <p class="font-semibold">${message}</p>
                <p class="text-xs text-gray-400">${timestamp}</p>
            </div>
        `;
        alertsContainer.prepend(alertEl);
        
        // Keep only last configured number of alerts to prevent memory issues
        const alerts = alertsContainer.querySelectorAll('div');
        if (alerts.length > window.CONFIG.APP.MAX_ALERTS) {
            alerts[alerts.length - 1].remove();
        }
    }

    // --- Event Listeners ---
    startButton.addEventListener('click', startAnalysis);
    stopButton.addEventListener('click', stopAnalysis);
    
    // Update UI state when dynamic alert checkbox changes
    dynamicAlertCheck.addEventListener('change', () => {
        if (isAnalyzing) {
            updateUIState();
        }
    });
    
    window.addEventListener('load', initWebcam);

    // Expose some functions for debugging in development
    if (window.CONFIG.ENVIRONMENT === 'development') {
        window.videoAnalysisDebug = {
            startAnalysis,
            stopAnalysis,
            addAlert,
            config: window.CONFIG
        };
    }

})();
