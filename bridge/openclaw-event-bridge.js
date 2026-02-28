/**
 * OpenClaw Event Bridge v1.0.0
 *
 * Trigger OpenClaw on ALL major TeamSpeak events and reply back in TeamSpeak.
 *
 * Events captured:
 *   - All chat messages (channel, DM, server)
 *   - User joins
 *   - User leaves/disconnects
 *   - Channel moves
 *
 * Flow:
 *   1) TeamSpeak event occurs (chat, join, move, etc.)
 *   2) Script formats the event and POSTs to OpenClaw /v1/chat/completions
 *   3) OpenClaw response is returned and sent back to TeamSpeak (if appropriate)
 */
registerPlugin({
    name: 'OpenClaw Event Bridge',
    version: '1.0.0',
    backends: ['ts3'],
    autorun: true,
    requiredModules: ['http'],
    description: 'Trigger OpenClaw on all major TeamSpeak events',
    author: 'OpenClaw',
    vars: [
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
            title: 'Rate limit (min ms between events per user)',
            type: 'number',
            placeholder: '5000',
            default: 5000
        },
        {
            name: 'inputValidationEnabled',
            title: 'Enable input validation/sanitization',
            type: 'checkbox',
            default: true
        },
        {
            name: 'trackChannelChat',
            title: 'Track channel chat messages',
            type: 'checkbox',
            default: true
        },
        {
            name: 'trackPrivateMessages',
            title: 'Track private messages (DMs)',
            type: 'checkbox',
            default: true
        },
        {
            name: 'trackServerMessages',
            title: 'Track server-wide messages',
            type: 'checkbox',
            default: true
        },
        {
            name: 'trackJoins',
            title: 'Track user joins',
            type: 'checkbox',
            default: true
        },
        {
            name: 'trackLeaves',
            title: 'Track user leaves/disconnects',
            type: 'checkbox',
            default: true
        },
        {
            name: 'trackMoves',
            title: 'Track channel moves',
            type: 'checkbox',
            default: true
        },
        {
            name: 'notifyChannelId',
            title: 'Notification channel ID (for join/leave/move events, optional)',
            type: 'string',
            placeholder: 'Leave empty to notify in the channel where event occurred'
        },
        {
            name: 'silentMode',
            title: 'Silent mode (send events to agent but no TeamSpeak replies for non-chat)',
            type: 'checkbox',
            default: false
        }
    ]
}, (_, config) => {
    const engine = require('engine')
    const event = require('event')
    const backend = require('backend')
    const http = require('http')

    const openclawUrl = (config.openclawUrl || '').trim()
    const openclawToken = (config.openclawToken || '').trim()
    const sessionKey = (config.sessionKey || '').trim()
    const agentId = (config.agentId || 'main').trim()
    const debugMode = !!config.debugMode
    const timeoutMs = Number(config.timeoutMs || 60000)
    const rateLimitEnabled = !!config.rateLimitEnabled
    const rateLimitMs = Number(config.rateLimitMs || 5000)
    const inputValidationEnabled = !!config.inputValidationEnabled
    
    const trackChannelChat = !!config.trackChannelChat
    const trackPrivateMessages = !!config.trackPrivateMessages
    const trackServerMessages = !!config.trackServerMessages
    const trackJoins = !!config.trackJoins
    const trackLeaves = !!config.trackLeaves
    const trackMoves = !!config.trackMoves
    const notifyChannelId = (config.notifyChannelId || '').trim()
    const silentMode = !!config.silentMode

    // Rate limit tracking: clientUid -> timestamp of last request
    const clientRequestTimes = {}

    function log(msg) {
        engine.log('[OpenClaw Event Bridge] ' + msg)
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
     * Send event to OpenClaw chatCompletions endpoint.
     * Calls callback(error, responseText).
     * 
     * @param {string} eventMessage - The formatted event message
     * @param {Function} callback - Callback function(error, responseText)
     */
    function notifyAgent(eventMessage, callback) {
        const url = openclawUrl.replace(/\/$/, '') + '/v1/chat/completions'

        const body = JSON.stringify({
            model: 'openclaw:' + agentId,
            messages: [
                { role: 'user', content: eventMessage }
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

        debugLog('Sending to agent: ' + eventMessage.substring(0, 100) + '...')

        http.simpleRequest({
            method: 'POST',
            url: url,
            timeout: timeoutMs,
            headers: headers,
            body: body
        }, (error, response) => {
            if (error) {
                log('chatCompletions error: ' + error)
                debugLog('Full error: ' + error)
                callback('Connection failed', null)
                return
            }

            debugLog('chatCompletions HTTP ' + response.statusCode)

            if (response.statusCode >= 400) {
                log('chatCompletions: HTTP ' + response.statusCode)
                callback('HTTP ' + response.statusCode, null)
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

                debugLog('Got response (' + text.length + ' chars)')
                callback(null, text)
            } catch (e) {
                log('chatCompletions parse error: ' + e)
                callback('Parse error', null)
            }
        })
    }

    /**
     * Check if client is rate-limited.
     * Returns { allowed: boolean }
     */
    function checkRateLimit(clientUid) {
        if (!rateLimitEnabled) return { allowed: true }

        const now = Date.now()
        const lastTime = clientRequestTimes[clientUid] || 0
        const elapsed = now - lastTime

        if (elapsed < rateLimitMs) {
            return { allowed: false }
        }

        clientRequestTimes[clientUid] = now
        return { allowed: true }
    }

    /**
     * Sanitize and validate user input.
     */
    function validateInput(message) {
        if (!inputValidationEnabled) return { valid: true, sanitized: message }

        let sanitized = message.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '')

        const maxLen = 4096
        if (sanitized.length > maxLen) {
            sanitized = sanitized.substring(0, maxLen)
        }

        if (!sanitized.trim()) {
            return { valid: false }
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
     */
    function respond(client, channel, mode, message) {
        const maxLen = 1024
        const chunks = []
        let pos = 0

        while (pos < message.length) {
            chunks.push(message.substring(pos, pos + maxLen))
            pos += maxLen
        }

        debugLog('Chunking response into ' + chunks.length + ' part(s)')

        chunks.forEach((chunk, index) => {
            if (mode === 2 && channel) {
                channel.chat(chunk)
            } else if (mode === 3 && channel) {
                backend.chat(chunk)
            } else {
                client.chat(chunk)
            }
            
            if (index < chunks.length - 1) {
                engine.sleep(100)
            }
        })
    }

    function isBotClient(client) {
        const botClient = backend.getBotClient()
        return botClient && client.uid() === botClient.uid()
    }

    // === CHAT EVENT ===
    event.on('chat', (ev) => {
        const text = ev.text || ''
        const client = ev.client
        const mode = ev.mode // 1=DM, 2=channel, 3=server
        const channel = ev.channel || null

        if (isBotClient(client)) return

        // Check if this event type is enabled
        if (mode === 1 && !trackPrivateMessages) return
        if (mode === 2 && !trackChannelChat) return
        if (mode === 3 && !trackServerMessages) return

        const clientName = client.name()
        const clientUid = client.uid()
        const channelName = channel ? channel.name() : 'Unknown'

        debugLog('Chat from ' + clientName + ' (mode=' + mode + '): ' + text)

        // Rate limit check
        const rateLimitCheck = checkRateLimit(clientUid)
        if (!rateLimitCheck.allowed) {
            debugLog('Rate limited: ' + clientName)
            return
        }

        // Validate input
        const inputCheck = validateInput(text)
        if (!inputCheck.valid) {
            log('Invalid input from ' + clientName)
            return
        }
        const cleanText = inputCheck.sanitized

        // Format event message
        let eventType = 'channel'
        if (mode === 1) eventType = 'DM'
        if (mode === 3) eventType = 'server'

        const eventMessage = '[TeamSpeak ' + eventType + '] ' + clientName + 
            (mode === 2 ? ' (in ' + channelName + ')' : '') + ': ' + cleanText

        log('Event: ' + eventType + ' from ' + clientName)

        notifyAgent(eventMessage, (error, response) => {
            if (error) {
                debugLog('Agent error: ' + error)
                return
            }

            if (response && response.trim()) {
                const resolvedClient = getClientByUid(clientUid)
                if (resolvedClient) {
                    const ch = channel ? backend.getChannelByID(channel.id()) : null
                    respond(resolvedClient, ch, mode, response)
                    debugLog('Sent response to ' + clientName)
                }
            }
        })
    })

    // === CLIENT CONNECT (JOIN) ===
    event.on('clientConnect', (ev) => {
        if (!trackJoins) return

        const client = ev.client
        if (isBotClient(client)) return

        const clientName = client.name()
        const clientUid = client.uid()
        const channel = client.getChannels()[0]
        const channelName = channel ? channel.name() : 'Unknown'

        debugLog('Join: ' + clientName + ' -> ' + channelName)

        const eventMessage = '[TeamSpeak join] ' + clientName + ' joined (in: ' + channelName + ')'
        log('Event: join - ' + clientName)

        notifyAgent(eventMessage, (error, response) => {
            if (error || silentMode) return

            if (response && response.trim()) {
                const resolvedClient = getClientByUid(clientUid)
                if (resolvedClient) {
                    const targetCh = notifyChannelId ? backend.getChannelByID(notifyChannelId) : channel
                    if (targetCh) {
                        targetCh.chat(response)
                        debugLog('Sent join response to channel')
                    }
                }
            }
        })
    })

    // === CLIENT DISCONNECT (LEAVE) ===
    event.on('clientDisconnect', (ev) => {
        if (!trackLeaves) return

        const client = ev.client
        if (isBotClient(client)) return

        const clientName = client.name()
        const reasonId = ev.reasonId || 0
        const reasonMsg = ev.reasonMsg || ''

        let reason = 'left'
        if (reasonId === 3) reason = 'lost connection'
        if (reasonId === 5) reason = 'kicked'
        if (reasonId === 6) reason = 'banned'
        if (reasonMsg) reason = reasonMsg

        debugLog('Leave: ' + clientName + ' (' + reason + ')')

        const eventMessage = '[TeamSpeak leave] ' + clientName + ' disconnected (' + reason + ')'
        log('Event: leave - ' + clientName)

        notifyAgent(eventMessage, (error, response) => {
            if (error || silentMode) return

            if (response && response.trim()) {
                const targetCh = notifyChannelId ? backend.getChannelByID(notifyChannelId) : null
                if (targetCh) {
                    targetCh.chat(response)
                    debugLog('Sent leave response to channel')
                }
            }
        })
    })

    // === CLIENT MOVE ===
    event.on('clientMove', (ev) => {
        if (!trackMoves) return

        const client = ev.client
        if (isBotClient(client)) return

        const clientName = client.name()
        const clientUid = client.uid()
        const fromChannel = ev.fromChannel
        const toChannel = ev.toChannel

        const fromName = fromChannel ? fromChannel.name() : 'Unknown'
        const toName = toChannel ? toChannel.name() : 'Unknown'

        debugLog('Move: ' + clientName + ' (' + fromName + ' -> ' + toName + ')')

        const eventMessage = '[TeamSpeak move] ' + clientName + ' moved from ' + fromName + ' to ' + toName
        log('Event: move - ' + clientName)

        notifyAgent(eventMessage, (error, response) => {
            if (error || silentMode) return

            if (response && response.trim()) {
                const resolvedClient = getClientByUid(clientUid)
                if (resolvedClient) {
                    const targetCh = notifyChannelId ? backend.getChannelByID(notifyChannelId) : toChannel
                    if (targetCh) {
                        targetCh.chat(response)
                        debugLog('Sent move response to channel')
                    }
                }
            }
        })
    })

    log('OpenClaw Event Bridge v1.0.0 initialized')
    log('Session: ' + sessionKey.substring(0, 20) + '...')
    log('Events tracked:')
    log('  - Channel chat: ' + (trackChannelChat ? 'ON' : 'OFF'))
    log('  - Private messages: ' + (trackPrivateMessages ? 'ON' : 'OFF'))
    log('  - Server messages: ' + (trackServerMessages ? 'ON' : 'OFF'))
    log('  - Joins: ' + (trackJoins ? 'ON' : 'OFF'))
    log('  - Leaves: ' + (trackLeaves ? 'ON' : 'OFF'))
    log('  - Moves: ' + (trackMoves ? 'ON' : 'OFF'))
    log('Silent mode: ' + (silentMode ? 'ON' : 'OFF'))
    log('Debug: ' + (debugMode ? 'ON' : 'OFF'))
})
