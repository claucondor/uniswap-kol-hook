# KOL Referral System Frontend

A modern React frontend for the KOL (Key Opinion Leader) Referral System, built with TypeScript, Tailwind CSS, and ethers.js.

## Features

- 🏠 **Dashboard** - Overview of system statistics and user metrics
- 🚰 **Faucet** - Request test tokens (KOLTEST1 & KOLTEST2)
- 🏆 **Leaderboard** - View KOL rankings and performance
- 🏊 **Pools** - Manage liquidity pools (coming soon)
- 👥 **Referrals** - Track referrals and earnings (coming soon)
- ⚙️ **Settings** - Account configuration (coming soon)

## Tech Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **Tailwind CSS** - Styling
- **React Router** - Navigation
- **Ethers.js** - Web3 integration
- **Axios** - HTTP client
- **Lucide React** - Icons
- **React Hot Toast** - Notifications

## Prerequisites

- Node.js 18+ 
- npm or yarn
- MetaMask or compatible wallet
- Base network configured in wallet

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd kol-referral-frontend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Environment setup**
   Create a `.env` file in the root directory:
   ```env
   VITE_API_URL=http://localhost:8080
   ```

4. **Start development server**
   ```bash
   npm run dev
   ```

5. **Open in browser**
   Navigate to `http://localhost:3000`

## Project Structure

```
src/
├── components/          # React components
│   ├── Layout.tsx      # Main layout with navigation
│   ├── Dashboard.tsx   # Dashboard page
│   └── Faucet.tsx      # Faucet page
├── config/             # Configuration files
│   └── contracts.ts    # Contract addresses and network config
├── hooks/              # Custom React hooks
│   └── useWeb3.ts      # Web3 wallet integration
├── lib/                # Utility functions
│   └── utils.ts        # Common utilities
├── services/           # API services
│   └── api.ts          # Backend API integration
├── types/              # TypeScript type definitions
│   └── index.ts        # Common types
├── App.tsx             # Main app component
├── main.tsx            # App entry point
└── index.css           # Global styles
```

## Configuration

### Contract Addresses

Contract addresses are configured in `src/config/contracts.ts`:

```typescript
export const CONTRACTS = {
  REFERRAL_REGISTRY: '0xacd17CefE9F105aaa839D802caD0B9BEE1f80F71',
  TVL_LEADERBOARD: '0x4839d26Aee01ffcC3bB432Cbc8024A9a388873ba',
  REFERRAL_HOOK: '0x32E3A98a7321a4054985fA8005945dE9a92B4500',
  KOLTEST1: '0x1c10beBe7c48ef1Ce90f673863A05aCCfD58b470',
  KOLTEST2: '0x9729e9b448EFf06aD848d4c80bff435119DA76d1',
};
```

### Network Configuration

The app is configured for Base mainnet:

```typescript
export const NETWORK = {
  chainId: 8453,
  name: 'Base',
  rpcUrl: 'https://mainnet.base.org',
  blockExplorer: 'https://basescan.org',
};
```

## Usage

### Connecting Wallet

1. Click "Connect Wallet" in the header
2. Approve the connection in MetaMask
3. Ensure you're on Base mainnet (chain ID: 8453)

### Using the Faucet

1. Navigate to the Faucet page
2. Ensure your wallet is connected
3. Click "Request Tokens"
4. Wait for the transaction confirmation
5. View transaction details in the response

### Rate Limiting

- 1 request per wallet address per 24 hours
- Rate limiting is enforced by the backend
- Failed requests will show appropriate error messages

## Development

### Available Scripts

```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run preview      # Preview production build
npm run lint         # Run ESLint
```

### Adding New Components

1. Create component file in `src/components/`
2. Add TypeScript interfaces in `src/types/`
3. Import and use in `App.tsx`
4. Add navigation item in `Layout.tsx`

### Styling

The project uses Tailwind CSS with custom components:

```css
.btn-primary    /* Primary button styles */
.btn-secondary  /* Secondary button styles */
.card           /* Card container styles */
.input-field    /* Input field styles */
```

## Backend Integration

The frontend integrates with the KOL Referral Backend API:

- **Base URL**: Configurable via `VITE_API_URL`
- **Endpoints**: Faucet, health checks
- **Authentication**: None required (public API)
- **Rate Limiting**: Handled by backend

## Deployment

### Build for Production

```bash
npm run build
```

### Deploy to Vercel

1. Connect repository to Vercel
2. Set environment variables
3. Deploy automatically on push

### Environment Variables

- `VITE_API_URL` - Backend API URL

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For support and questions:
- Create an issue in the repository
- Check the documentation
- Review the backend API documentation 