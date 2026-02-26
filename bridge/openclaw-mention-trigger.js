/**
 * OpenClaw Mention Bridge v1.0.0
 *
 * Trigger OpenClaw on @-mentions in TeamSpeak and reply back in TeamSpeak.
 *
 * Flow:
 *   1) User sends a TeamSpeak message containing the trigger prefix.
 *   2) Script POSTs to OpenClaw /v1/chat/completions using the configured session.
 *   3) OpenClaw response is returned via HTTP and sent back to the user/channel.
 */
registerPlugin({
    name: 'OpenClaw Mention Bridge',
    version: '1.0.0',
    backends: ['ts3'],
    autorun: true,
    requiredModules: ['http'],
    description: 'Trigger OpenClaw on @-mentions and reply in TeamSpeak',
    author: 'OpenClaw',
    vars: [
        {
            name: 'triggerPrefix',
            title: 'Trigger prefix (case-insensitive)',
            type: 'string',
            placeholder: '@assistant',
            default: '@assistant'
        },
        {
            name: 'openclawUrl',
            title: 'OpenClaw Gateway URL',
            type: 'string',
            placeholder: 'http://localhost:18789',
            default: 'http://localhost:18789'
        },
        {
            name: 'openclawToken',
            title: 'OpenClaw Gateway token (optional if not required)',
            type: 'string',
            placeholder: 'your_gateway_token'
        },
        {
            name: 'sessionKey',
            title: 'OpenClaw session key (x-openclaw-session-key)',
            type: 'string',
            placeholder: 'agent:youragent:discord:channel:<id>'
        },
        {
            name: 'agentId',
            title: 'OpenClaw agent id',
            type: 'string',
            placeholder: 'main',
            default: 'main'
        },
        {
            name: 'debugMode',
            title: 'Enable debug logging',
            type: 'checkbox',
            default: false
        },
        {
            name: 'timeoutMs',
            title: 'HTTP timeout (ms)',
            type: 'number',
            placeholder: '60000',
            default: 60000
        },
        {
            name: 'rateLimitEnabled',
            title: 'Enable rate limiting',
            type: 'checkbox',
            default: true
        },
        {
            name: 'rateLimitMs',
            title: 'Rate limit (min ms between mentions per user)',
            type: 'number',
            placeholder: '2000',
            default: 2000
        },
        {
            name: 'inputValidationEnabled',
            title: 'Enable input validation/sanitization',
            type: 'checkbox',
            default: true
        }
    ]
}, (_, config) => {
    const engine = require('engine')
    const event = require('event')
    const backend = require('backend')
    const http = require('http')

    const triggerPrefix = (config.triggerPrefix || '@assistant').trim()
    const openclawUrl = (config.openclawUrl || '').trim()
    const openclawToken = (config.openclawToken || '').trim()
    const sessionKey = (config.sessionKey || '').trim()
    const agentId = (config.agentId || 'main').trim()
    const debugMode = !!config.debugMode
    const timeoutMs = Number(config.timeoutMs || 60000)
    const rateLimitEnabled = !!config.rateLimitEnabled
    const rateLimitMs = Number(config.rateLimitMs || 2000)
    const inputValidationEnabled = !!config.inputValidationEnabled

    // Rate limit tracking: clientUid -> timestamp of last request
    const clientRequestTimes = {}

    function log(msg) {
        engine.log('[OpenClaw Mention Bridge] ' + msg)
    }

    function debugLog(msg) {
        if (debugMode) {
            log('[DEBUG] ' + msg)
        }
    }

    if (!openclawUrl) {
        log('Missing OpenClaw URL. Set "OpenClaw Gateway URL" in the script settings.')
        return
    }

    if (!sessionKey) {
        log('Missing session key. Set "OpenClaw session key" in the script settings.')
        return
    }

    /**
     * Send a message to the OpenClaw chatCompletions endpoint.
     * Calls callback(error, responseText).
     * 
     * @param {string} userName - The TeamSpeak username
     * @param {string} userMessage - The user's message
     * @param {Function} callback - Callback function(error, responseText)
     */
    function askAgent(userName, userMessage, callback) {
        const url = openclawUrl.replace(/\/$/, '') + '/v1/chat/completions'

        const fullMessage = '[TeamSpeak — ' + userName + ']: ' + userMessage
        const body = JSON.stringify({
            model: 'openclaw:' + agentId,
            messages: [
                { role: 'user', content: fullMessage }
            ],
            user: 'teamspeak-bridge'
        })

        const headers = {
            'Content-Type': 'application/json',
            'x-openclaw-session-key': sessionKey
        }

        if (openclawToken) {
            headers['Authorization'] = 'Bearer ' + openclawToken
        }

        debugLog('Sending to chatCompletions: ' + fullMessage)

        http.simpleRequest({
            method: 'POST',
            url: url,
            timeout: timeoutMs,
            headers: headers,
            body: body
        }, (error, response) => {
            if (error) {
                const errorMsg = 'Connection failed. Check if OpenClaw gateway is running at ' + openclawUrl
                log('chatCompletions error: ' + error)
                debugLog('Full error: ' + error)
                callback(errorMsg, null)
                return
            }

            debugLog('chatCompletions HTTP ' + response.statusCode)

            if (response.statusCode === 401) {
                const errorMsg = 'Authentication failed. Check your gateway token and session key.'
                log('chatCompletions: HTTP 401 (auth failed)')
                callback(errorMsg, null)
                return
            }

            if (response.statusCode === 404) {
                const errorMsg = 'OpenClaw endpoint not found. Check your gateway URL.'
                log('chatCompletions: HTTP 404 (not found)')
                callback(errorMsg, null)
                return
            }

            if (response.statusCode >= 500) {
                const errorMsg = 'OpenClaw server error (HTTP ' + response.statusCode + '). Try again later.'
                log('chatCompletions: HTTP ' + response.statusCode + ' (server error)')
                callback(errorMsg, null)
                return
            }

            if (response.statusCode >= 400) {
                const errorMsg = 'Request error (HTTP ' + response.statusCode + '). Check your configuration.'
                log('chatCompletions: HTTP ' + response.statusCode + ' — ' + (response.data || '').substring(0, 100))
                callback(errorMsg, null)
                return
            }

            try {
                const data = JSON.parse(response.data)
                let text = ''

                if (data.choices && data.choices.length > 0) {
                    const choice = data.choices[0]
                    if (choice.message && choice.message.content) {
                        text = choice.message.content
                    }
                }

                if (!text) {
                    log('chatCompletions: empty response body')
                    callback('No response from agent', null)
                    return
                }

                debugLog('Got response (' + text.length + ' chars)')
                callback(null, text)
            } catch (e) {
                const errorMsg = 'Failed to parse OpenClaw response. Check the gateway logs.'
                log('chatCompletions parse error: ' + e + ' | raw: ' + (response.data || '').substring(0, 200))
                debugLog('Full parse error: ' + e)
                callback(errorMsg, null)
            }
        })
    }

    /**
     * Check if client is rate-limited.
     * Returns { allowed: boolean, message?: string }
     */
    function checkRateLimit(clientUid) {
        if (!rateLimitEnabled) return { allowed: true }

        const now = Date.now()
        const lastTime = clientRequestTimes[clientUid] || 0
        const elapsed = now - lastTime

        if (elapsed < rateLimitMs) {
            const waitMs = rateLimitMs - elapsed
            return {
                allowed: false,
                message: 'Please wait ' + Math.ceil(waitMs / 1000) + 's before mentioning again.'
            }
        }

        clientRequestTimes[clientUid] = now
        return { allowed: true }
    }

    /**
     * Sanitize and validate user input.
     * Removes control characters and limits length.
     */
    function validateInput(message) {
        if (!inputValidationEnabled) return { valid: true, sanitized: message }

        // Remove control characters (but keep newlines, tabs)
        let sanitized = message.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '')

        // Limit to reasonable length (prevent abuse)
        const maxLen = 4096
        if (sanitized.length > maxLen) {
            sanitized = sanitized.substring(0, maxLen)
        }

        // Ensure not empty after sanitization
        if (!sanitized.trim()) {
            return { valid: false, message: 'Message is empty after validation.' }
        }

        return { valid: true, sanitized: sanitized.trim() }
    }

    function getClientByUid(uid) {
        const clients = backend.getClients()
        for (let i = 0; i < clients.length; i++) {
            if (clients[i].uid() === uid) return clients[i]
        }
        return null
    }

    /**
     * Send message to client/channel, chunking if necessary.
     * TeamSpeak has a 1024-character limit per message.
     * Longer messages are automatically split and sent as multiple messages.
     */
    function respond(client, channel, mode, message) {
        const maxLen = 1024
        const chunks = []
        let pos = 0

        while (pos < message.length) {
            chunks.push(message.substring(pos, pos + maxLen))
            pos += maxLen
        }

        debugLog('Chunking response into ' + chunks.length + ' part(s) for delivery')

        chunks.forEach((chunk, index) => {
            if (mode === 2 && channel) {
                channel.chat(chunk)
            } else {
                client.chat(chunk)
            }
            
            if (index < chunks.length - 1) {
                // Small delay between chunks to prevent rate limiting
                require('engine').sleep(100)
            }
        })
    }

    event.on('chat', (ev) => {
        const text = ev.text || ''
        const client = ev.client
        const mode = ev.mode
        const channel = ev.channel || null

        const botClient = backend.getBotClient()
        if (botClient && client.uid() === botClient.uid()) {
            return
        }

        const clientName = client.name()
        const clientUid = client.uid()

        debugLog('Chat from ' + clientName + ' (mode=' + mode + '): ' + text)

        const lowerText = text.toLowerCase()
        const hasTrigger = lowerText.indexOf(triggerPrefix.toLowerCase()) !== -1
        if (!hasTrigger) return

        // Check rate limit
        const rateLimitCheck = checkRateLimit(clientUid)
        if (!rateLimitCheck.allowed) {
            log('Rate limited: ' + clientName + ' (' + clientUid + ')')
            const ch = channelId ? backend.getChannelByID(channelId) : null
            respond(client, ch, mode, '[OpenClaw] ' + rateLimitCheck.message)
            return
        }

        let cleanMessage = text
        const regex = new RegExp(triggerPrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi')
        cleanMessage = cleanMessage.replace(regex, '').trim()
        cleanMessage = cleanMessage.replace(/<@\d+\|[^>]+>/g, '').trim()

        if (!cleanMessage) {
            cleanMessage = 'hello'
        }

        // Validate input
        const inputCheck = validateInput(cleanMessage)
        if (!inputCheck.valid) {
            log('Invalid input from ' + clientName + ': ' + inputCheck.message)
            const ch = channelId ? backend.getChannelByID(channelId) : null
            respond(client, ch, mode, '[OpenClaw] ' + inputCheck.message)
            return
        }
        cleanMessage = inputCheck.sanitized

        log('Trigger from ' + clientName + ' (mode=' + mode + '): ' + cleanMessage)

        const channelId = channel ? channel.id() : null

        askAgent(clientName, cleanMessage, (error, response) => {
            const resolvedClient = getClientByUid(clientUid)

            if (error) {
                if (resolvedClient) {
                    respond(
                        resolvedClient,
                        channelId ? backend.getChannelByID(channelId) : null,
                        mode,
                        '[OpenClaw] Sorry, something went wrong: ' + error
                    )
                }
                return
            }

            if (resolvedClient) {
                const ch = channelId ? backend.getChannelByID(channelId) : null
                respond(resolvedClient, ch, mode, response)
                debugLog('Sent response to ' + clientName + ' (mode=' + mode + ', ' + response.length + ' chars)')
            } else {
                log('Client ' + clientName + ' (' + clientUid + ') no longer connected')
            }
        })
    })

    log('OpenClaw Mention Bridge v1.0.0 initialized')
    log('Trigger: ' + triggerPrefix)
    log('Session: ' + sessionKey.substring(0, 20) + '...')
    log('Debug: ' + (debugMode ? 'ON' : 'OFF'))
    log('Rate limiting: ' + (rateLimitEnabled ? 'ON (' + rateLimitMs + 'ms)' : 'OFF'))
    log('Input validation: ' + (inputValidationEnabled ? 'ON' : 'OFF'))
})
