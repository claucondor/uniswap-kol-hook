# KOL Referral System Backend API

## Overview

The KOL Referral System Backend provides a REST API for managing the referral system, including a faucet for distributing test tokens.

## Base URL

- **Development**: `http://localhost:8080`
- **Production**: `https://api.kol-referral.com` (example)

## Endpoints

### 1. Health Check

**GET** `/`

Check if the backend is running.

```bash
curl http://localhost:8080/
```

**Response:**
```
KOL Referral Backend is running!
```

### 2. Request Test Tokens

**POST** `/api/faucet`

Request KOLTEST1 and KOLTEST2 tokens from the faucet.

**Rate Limiting:**
- 1 request per user address per 24 hours
- Rate limiting is based on user address

**Request Body:**
```json
{
  "userAddress": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6"
}
```

**Example Request:**
```bash
curl -X POST http://localhost:8080/api/faucet \
  -H "Content-Type: application/json" \
  -d '{
    "userAddress": "0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6"
  }'
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Tokens sent successfully.",
  "txHash1": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
  "txHash2": "0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321"
}
```

**Error Responses:**

**400 Bad Request** - Invalid address:
```json
{
  "success": false,
  "message": "Valid userAddress is required."
}
```

**429 Too Many Requests** - Rate limit exceeded:
```json
{
  "success": false,
  "message": "Rate limit exceeded. Please try again later."
}
```

**500 Internal Server Error:**
```json
{
  "success": false,
  "message": "Internal Server Error while processing faucet request."
}
```

### 3. Faucet Health Check

**GET** `/api/faucet/health`

Check if the faucet service is healthy.

```bash
curl http://localhost:8080/api/faucet/health
```

**Response:**
```json
{
  "status": "Faucet route is healthy"
}
```

## JavaScript/TypeScript Examples

### Using fetch

```javascript
// Request tokens from faucet
async function requestTokens(userAddress) {
  try {
    const response = await fetch('http://localhost:8080/api/faucet', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userAddress: userAddress
      })
    });
    
    const data = await response.json();
    
    if (response.ok) {
      console.log('Tokens sent successfully!');
      console.log('KOLTEST1 tx:', data.txHash1);
      console.log('KOLTEST2 tx:', data.txHash2);
    } else {
      console.error('Error:', data.message);
    }
  } catch (error) {
    console.error('Network error:', error);
  }
}

// Usage
requestTokens('0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6');
```

### Using axios

```javascript
import axios from 'axios';

// Request tokens from faucet
async function requestTokens(userAddress) {
  try {
    const response = await axios.post('http://localhost:8080/api/faucet', {
      userAddress: userAddress
    });
    
    console.log('Tokens sent successfully!');
    console.log('KOLTEST1 tx:', response.data.txHash1);
    console.log('KOLTEST2 tx:', response.data.txHash2);
    
    return response.data;
  } catch (error) {
    if (error.response) {
      console.error('API Error:', error.response.data.message);
    } else {
      console.error('Network error:', error.message);
    }
  }
}
```

## Python Examples

### Using requests

```python
import requests
import json

def request_tokens(user_address):
    url = "http://localhost:8080/api/faucet"
    payload = {
        "userAddress": user_address
    }
    
    try:
        response = requests.post(url, json=payload)
        data = response.json()
        
        if response.status_code == 200:
            print("Tokens sent successfully!")
            print(f"KOLTEST1 tx: {data['txHash1']}")
            print(f"KOLTEST2 tx: {data['txHash2']}")
        else:
            print(f"Error: {data['message']}")
            
    except requests.exceptions.RequestException as e:
        print(f"Network error: {e}")

# Usage
request_tokens("0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6")
```

## Configuration

The faucet amounts are configured via environment variables:

- `FAUCET_AMOUNT_KOLTEST1_STR`: Amount of KOLTEST1 tokens to send (e.g., "100")
- `FAUCET_AMOUNT_KOLTEST2_STR`: Amount of KOLTEST2 tokens to send (e.g., "100")

## Error Handling

The API returns appropriate HTTP status codes:

- **200**: Success
- **400**: Bad Request (invalid input)
- **429**: Too Many Requests (rate limit exceeded)
- **500**: Internal Server Error

All error responses include a `message` field with a human-readable description.

## Rate Limiting

The faucet implements rate limiting to prevent abuse:

- **Limit**: 1 request per user address per 24 hours
- **Window**: 24 hours (86,400,000 milliseconds)
- **Key**: User's Ethereum address

Rate limit information is stored in memory. For production, consider using Redis or a database for persistence.

## Security

- CORS is enabled for all routes
- Security headers are automatically added
- Input validation for Ethereum addresses
- Rate limiting to prevent abuse

## OpenAPI Specification

A complete OpenAPI 3.0.3 specification is available in `openapi.yaml` for integration with API documentation tools like Swagger UI or Redoc. 