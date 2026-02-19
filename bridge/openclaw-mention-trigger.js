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
                log('chatCompletions error: ' + error)
                callback('Request failed: ' + error, null)
                return
            }

            debugLog('chatCompletions HTTP ' + response.statusCode)

            if (response.statusCode >= 400) {
                log('chatCompletions HTTP ' + response.statusCode + ': ' + response.data)
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

                if (!text) {
                    log('chatCompletions: empty response body')
                    callback('Empty response', null)
                    return
                }

                debugLog('Got response (' + text.length + ' chars)')
                callback(null, text)
            } catch (e) {
                log('chatCompletions parse error: ' + e + ' | raw: ' + (response.data || '').substring(0, 200))
                callback('Parse error', null)
            }
        })
    }

    function getClientByUid(uid) {
        const clients = backend.getClients()
        for (let i = 0; i < clients.length; i++) {
            if (clients[i].uid() === uid) return clients[i]
        }
        return null
    }

    function respond(client, channel, mode, message) {
        if (mode === 2 && channel) {
            channel.chat(message)
        } else {
            client.chat(message)
        }
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

        let cleanMessage = text
        const regex = new RegExp(triggerPrefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi')
        cleanMessage = cleanMessage.replace(regex, '').trim()
        cleanMessage = cleanMessage.replace(/<@\d+\|[^>]+>/g, '').trim()

        if (!cleanMessage) {
            cleanMessage = 'hello'
        }

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

            const maxLen = 1024
            let tsResponse = response
            if (tsResponse.length > maxLen) {
                tsResponse = tsResponse.substring(0, maxLen - 20) + '... (truncated)'
            }

            if (resolvedClient) {
                const ch = channelId ? backend.getChannelByID(channelId) : null
                respond(resolvedClient, ch, mode, tsResponse)
                debugLog('Sent response to ' + clientName + ' (mode=' + mode + ', ' + tsResponse.length + ' chars)')
            } else {
                log('Client ' + clientName + ' (' + clientUid + ') no longer connected')
            }
        })
    })

    log('OpenClaw Mention Bridge v1.0.0 initialized')
    log('Trigger: ' + triggerPrefix)
    log('Session: ' + sessionKey)
    log('Debug: ' + (debugMode ? 'ON' : 'OFF'))
})
