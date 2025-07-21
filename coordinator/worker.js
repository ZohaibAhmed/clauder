// Cloudflare Worker for Claude Code Remote passcode coordination
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    
    // CORS headers
    const headers = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Content-Type': 'application/json',
    };
    
    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers });
    }
    
    try {
      // POST /register - Register new session
      if (url.pathname === '/register' && request.method === 'POST') {
        const { passcode, tunnel_url, token } = await request.json();
        
        // Validate input
        if (!passcode || !tunnel_url || !token) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Missing required fields: passcode, tunnel_url, token',
          }), { status: 400, headers });
        }
        
        // Validate passcode format (6-character alphanumeric)
        const passcodeRegex = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/;
        if (!passcodeRegex.test(passcode)) {
          return new Response(JSON.stringify({
            success: false,
            error: 'Invalid passcode format. Expected: 6-character alphanumeric code (e.g. ABC123)',
          }), { status: 400, headers });
        }
        
        // Store session data in KV with 24-hour expiration
        const sessionData = { 
          tunnel_url, 
          token, 
          created_at: Date.now(),
          expires_at: Date.now() + (24 * 60 * 60 * 1000) // 24 hours
        };
        
        await env.SESSIONS.put(passcode, JSON.stringify(sessionData), {
          expirationTtl: 86400, // 24 hours in seconds
        });
        
        return new Response(JSON.stringify({
          success: true,
          passcode: passcode,
          expires_in: 86400,
          message: 'Session registered successfully',
        }), { headers });
      }
      
      // GET /lookup/:passcode - Get session details
      if (url.pathname.startsWith('/lookup/') && request.method === 'GET') {
        const passcode = url.pathname.split('/')[2];
        
        if (!passcode) {
          return new Response(JSON.stringify({
            error: 'Passcode is required',
          }), { status: 400, headers });
        }
        
        const sessionDataRaw = await env.SESSIONS.get(passcode);
        
        if (!sessionDataRaw) {
          return new Response(JSON.stringify({
            error: 'Invalid or expired passcode',
          }), { status: 404, headers });
        }
        
        const sessionData = JSON.parse(sessionDataRaw);
        
        // Check if session is expired (extra safety check)
        if (Date.now() > sessionData.expires_at) {
          // Clean up expired session
          await env.SESSIONS.delete(passcode);
          return new Response(JSON.stringify({
            error: 'Passcode has expired',
          }), { status: 404, headers });
        }
        
        return new Response(JSON.stringify({
          tunnel_url: sessionData.tunnel_url,
          token: sessionData.token,
          created_at: sessionData.created_at,
          expires_at: sessionData.expires_at,
        }), { headers });
      }
      
      // GET /health - Health check
      if (url.pathname === '/health' && request.method === 'GET') {
        return new Response(JSON.stringify({
          status: 'ok',
          timestamp: Date.now(),
          version: '1.0.0',
        }), { headers });
      }
      
      // GET / - API documentation
      if (url.pathname === '/' && request.method === 'GET') {
        const docs = {
          name: 'Claude Code Remote Coordinator',
          version: '1.0.0',
          description: 'Coordinates passcode-based connections between Mac and iOS devices',
          endpoints: {
            'POST /register': 'Register a new session with passcode, tunnel_url, and token',
            'GET /lookup/:passcode': 'Get session details for a passcode',
            'GET /health': 'Health check endpoint',
          },
          example: {
            register: {
              method: 'POST',
              url: '/register',
              body: {
                passcode: 'ABC123',
                tunnel_url: 'https://abc123.lhr.life',
                token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
              }
            },
            lookup: {
              method: 'GET',
              url: '/lookup/ABC123',
            }
          }
        };
        
        return new Response(JSON.stringify(docs, null, 2), { 
          headers: { ...headers, 'Content-Type': 'application/json' }
        });
      }
      
      // 404 for unknown routes
      return new Response(JSON.stringify({
        error: 'Endpoint not found',
        available_endpoints: ['/register', '/lookup/:passcode', '/health', '/'],
      }), { status: 404, headers });
      
    } catch (error) {
      console.error('Worker error:', error);
      return new Response(JSON.stringify({
        error: 'Internal server error',
        message: error.message,
      }), { status: 500, headers });
    }
  },
};