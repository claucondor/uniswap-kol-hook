"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const hono_1 = require("hono");
const http_exception_1 = require("hono/http-exception");
const leaderboardService_1 = require("../services/leaderboardService");
const leaderboard = new hono_1.Hono();
// Get current leaderboard (top KOLs)
leaderboard.get('/', async (c) => {
    try {
        console.log('Getting current leaderboard...');
        const result = await (0, leaderboardService_1.getLeaderboard)();
        if (!result.success) {
            return c.json(result, 500);
        }
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in GET /api/leaderboard:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting leaderboard.' });
    }
});
// Get current epoch
leaderboard.get('/epoch', async (c) => {
    try {
        console.log('Getting current epoch...');
        const result = await (0, leaderboardService_1.getCurrentEpoch)();
        if (!result.success) {
            return c.json(result, 500);
        }
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in GET /api/leaderboard/epoch:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting current epoch.' });
    }
});
// Get leaderboard for specific epoch
leaderboard.get('/epoch/:epochNumber', async (c) => {
    try {
        const epochNumber = c.req.param('epochNumber');
        if (!epochNumber || isNaN(Number(epochNumber))) {
            return c.json({ success: false, message: 'Valid epoch number is required.' }, 400);
        }
        console.log(`Getting leaderboard for epoch ${epochNumber}...`);
        const result = await (0, leaderboardService_1.getEpochLeaderboard)(Number(epochNumber));
        if (!result.success) {
            return c.json(result, 404);
        }
        return c.json(result, 200);
    }
    catch (error) {
        console.error('Error in GET /api/leaderboard/epoch/:epochNumber:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting epoch leaderboard.' });
    }
});
// Get KOL ranking (position in leaderboard)
leaderboard.get('/kol/:kolAddress/ranking', async (c) => {
    try {
        const kolAddress = c.req.param('kolAddress');
        if (!kolAddress) {
            return c.json({ success: false, message: 'KOL address is required.' }, 400);
        }
        console.log(`Getting ranking for KOL ${kolAddress}...`);
        // Get full leaderboard and find KOL position
        const result = await (0, leaderboardService_1.getLeaderboard)();
        if (!result.success) {
            return c.json(result, 500);
        }
        const kols = result.data?.kols || [];
        const kolIndex = kols.findIndex((kol) => kol.address.toLowerCase() === kolAddress.toLowerCase());
        if (kolIndex === -1) {
            return c.json({
                success: false,
                message: 'KOL not found in leaderboard'
            }, 404);
        }
        return c.json({
            success: true,
            message: 'KOL ranking retrieved successfully',
            data: {
                kolAddress: kolAddress.toLowerCase(),
                position: kolIndex + 1,
                totalKOLs: kols.length,
                stats: kols[kolIndex]
            }
        }, 200);
    }
    catch (error) {
        console.error('Error in GET /api/leaderboard/kol/ranking:', error);
        throw new http_exception_1.HTTPException(500, { message: 'Internal Server Error while getting KOL ranking.' });
    }
});
// Health check
leaderboard.get('/health', (c) => {
    return c.json({
        status: 'Leaderboard routes healthy',
        endpoints: [
            'GET / - Get current leaderboard',
            'GET /epoch - Get current epoch',
            'GET /epoch/:number - Get epoch leaderboard',
            'GET /kol/:address/ranking - Get KOL ranking'
        ]
    });
});
exports.default = leaderboard;
