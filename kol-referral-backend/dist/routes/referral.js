"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const hono_1 = require("hono");
const http_exception_1 = require("hono/http-exception");
const ethers_1 = require("ethers");
const referralService_1 = require("../services/referralService");
const referral = new hono_1.Hono();
// Register a new KOL
referral.post('/kol/register', async (c) => {
    try {
        const body = await c.req.json();
        const { kolAddress, referralCode, socialHandle, metadataUri } = body;
        // Validation
        if (!kolAddress || !ethers_1.ethers.isAddress(kolAddress)) {
            return c.json({ success: false, message: 'Valid kolAddress is required.' }, 400);
        }
        if (!referralCode || referralCode.length < 3) {
            return c.json({ success: false, message: 'Referral code must be at least 3 characters.' }, 400);
        }
        if (!socialHandle || socialHandle.length < 1) {
            return c.json({ success: false, message: 'Social handle is required.' }, 400);
        }
        console.log(`Registering KOL: ${kolAddress} with code: ${referralCode}`);
        const result = await (0, referralService_1.registerKOL)(kolAddress, referralCode, socialHandle, metadataUri);
        if (!result.success) {
            return c.json(result, 400);
        }
        return c.json(result, 201);
    }
    catch (error) {
        console.error('Error in POST /api/referral/kol/register:', error);
        if (error instanceof SyntaxError) {
            return c.json({ success: false, message: 'Invalid JSON payload.' }, 400);
        }
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while registering KOL.' });
    }
});
// Register a referred user
referral.post('/user/register', async (c) => {
    try {
        const body = await c.req.json();
        const { userAddress, referralCode } = body;
        // Validation
        if (!userAddress || !ethers_1.ethers.isAddress(userAddress)) {
            return c.json({ success: false, message: 'Valid userAddress is required.' }, 400);
        }
        if (!referralCode) {
            return c.json({ success: false, message: 'Referral code is required.' }, 400);
        }
        console.log(`Registering referred user: ${userAddress} with code: ${referralCode}`);
        const result = await (0, referralService_1.registerReferredUser)(userAddress, referralCode);
        if (!result.success) {
            return c.json(result, 400);
        }
        return c.json(result, 201);
    }
    catch (error) {
        console.error('Error in POST /api/referral/user/register:', error);
        if (error instanceof SyntaxError) {
            return c.json({ success: false, message: 'Invalid JSON payload.' }, 400);
        }
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while registering referred user.' });
    }
});
// Get referral info by code
referral.get('/code/:referralCode', async (c) => {
    try {
        const referralCode = c.req.param('referralCode');
        if (!referralCode) {
            return c.json({ success: false, message: 'Referral code is required.' }, 400);
        }
        console.log(`Getting referral info for code: ${referralCode}`);
        const result = await (0, referralService_1.getReferralInfo)(referralCode);
        if (!result.success) {
            return c.json(result, 404);
        }
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in GET /api/referral/code:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting referral info.' });
    }
});
// Get user referral info
referral.get('/user/:userAddress', async (c) => {
    try {
        const userAddress = c.req.param('userAddress');
        if (!userAddress || !ethers_1.ethers.isAddress(userAddress)) {
            return c.json({ success: false, message: 'Valid userAddress is required.' }, 400);
        }
        console.log(`Getting user referral info for: ${userAddress}`);
        const result = await (0, referralService_1.getReferralInfo)(userAddress, true);
        if (!result.success) {
            return c.json(result, 404);
        }
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in GET /api/referral/user:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting user referral info.' });
    }
});
// Get KOL stats
referral.get('/kol/:kolAddress/stats', async (c) => {
    try {
        const kolAddress = c.req.param('kolAddress');
        if (!kolAddress || !ethers_1.ethers.isAddress(kolAddress)) {
            return c.json({ success: false, message: 'Valid kolAddress is required.' }, 400);
        }
        console.log(`Getting KOL stats for: ${kolAddress}`);
        const result = await (0, referralService_1.getKOLStats)(kolAddress);
        if (!result.success) {
            return c.json(result, 404);
        }
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in GET /api/referral/kol/stats:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting KOL stats.' });
    }
});
// Health check
referral.get('/health', (c) => {
    return c.json({
        status: 'Referral routes healthy',
        endpoints: [
            'POST /kol/register - Register KOL',
            'POST /user/register - Register referred user',
            'GET /code/:code - Get referral by code',
            'GET /user/:address - Get user referral info',
            'GET /kol/:address/stats - Get KOL stats'
        ]
    });
});
exports.default = referral;
