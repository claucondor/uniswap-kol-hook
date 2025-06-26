# Sesión 11: Periphery - Swap + Bridge Router

## Objetivos de Aprendizaje

Al completar esta sesión, serás capaz de:

1. **Entender Router Contracts**: Comprender qué son los contratos router y cuándo usarlos vs hooks
2. **Arquitectura de Periphery**: Distinguir entre hooks y contratos de periferia
3. **Bridge Integration**: Integrar funcionalidad de bridging nativo con swaps
4. **Router Design Patterns**: Implementar patrones de diseño para routers personalizados
5. **Cross-Chain Workflows**: Combinar operaciones DeFi con transferencias cross-chain

## Introducción Conceptual

### Router vs Hook: ¿Cuándo usar cada uno?

**Hooks** son ideales cuando:
- Necesitas modificar la lógica interna del pool
- Quieres interceptar eventos específicos (beforeSwap, afterSwap, etc.)
- La funcionalidad está estrechamente ligada al pool

**Routers** son mejores cuando:
- Necesitas orquestar múltiples contratos externos
- Quieres combinar operaciones DeFi con servicios externos
- La lógica es más sobre flujo de trabajo que modificación de pool

### Arquitectura del Sistema

```
EOA → Router Contract → Pool Manager → Hook (opcional)
  ↓
External Services (Bridges, Oracles, etc.)
```

En esta sesión construiremos un router que:
1. Recibe tokens del usuario
2. Ejecuta un swap en Uniswap v4
3. Envía los tokens resultantes a Optimism L2 via bridge nativo

## Implementación Completa

### Setup del Proyecto

```bash
# Inicializar proyecto Foundry
forge init swap-and-bridge-op

# Instalar dependencias
cd swap-and-bridge-op
forge install Uniswap/v4-periphery
forge install ethereum-optimism/optimism

# Configurar remappings
forge remappings > remappings.txt

# Limpiar archivos default
rm ./**/Counter*.sol
```

**foundry.toml**:
```toml
[profile.default]
solc_version = '0.8.26'
evm_version = "cancun"
optimizer_runs = 800
via_ir = false
ffi = true

[rpc_endpoints]
sepolia = "https://rpc.sepolia.org/"
op_sepolia = "https://sepolia.optimism.io"
```

### Contrato Principal: SwapAndBridgeOptimismRouter

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {TransientStateLibrary} from "v4-core/libraries/TransientStateLibrary.sol";

// Interface para el bridge nativo de Optimism
interface IL1StandardBridge {
    function depositETHTo(
        address _to,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external payable;
    
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

contract SwapAndBridgeOptimismRouter is Ownable {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using TransientStateLibrary for IPoolManager;

    // Contratos core
    IPoolManager public immutable manager;
    IL1StandardBridge public immutable l1StandardBridge;
    
    // Mapping de tokens L1 → L2 para bridging
    mapping(address l1Token => address l2Token) public l1ToL2TokenAddresses;

    // Structs para organizar datos
    struct CallbackData {
        address sender;
        SwapSettings settings;
        PoolKey key;
        IPoolManager.SwapParams params;
        bytes hookData;
    }

    struct SwapSettings {
        bool bridgeTokens;        // ¿Hacer bridge después del swap?
        address recipientAddress; // Dirección en L2 para recibir tokens
    }

    // Errores personalizados
    error CallerNotManager();
    error TokenCannotBeBridged();

    constructor(
        IPoolManager _manager,
        IL1StandardBridge _l1StandardBridge
    ) Ownable(msg.sender) {
        manager = _manager;
        l1StandardBridge = _l1StandardBridge;
    }

    // Función para que el owner agregue tokens soportados
    function addL1ToL2TokenAddress(
        address l1Token,
        address l2Token
    ) external onlyOwner {
        l1ToL2TokenAddresses[l1Token] = l2Token;
    }

    // Función principal: swap + bridge opcional
    function swap(
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        SwapSettings memory settings,
        bytes memory hookData
    ) external payable returns (BalanceDelta delta) {
        // Validar que el token se puede hacer bridge si se solicita
        if (settings.bridgeTokens) {
            Currency l1TokenToBridge = params.zeroForOne
                ? key.currency1
                : key.currency0;

            if (!l1TokenToBridge.isNative()) {
                address l2Token = l1ToL2TokenAddresses[
                    Currency.unwrap(l1TokenToBridge)
                ];
                if (l2Token == address(0)) revert TokenCannotBeBridged();
            }
        }

        // Desbloquear Pool Manager para ejecutar swap
        delta = abi.decode(
            manager.unlock(
                abi.encode(
                    CallbackData(msg.sender, settings, key, params, hookData)
                )
            ),
            (BalanceDelta)
        );

        // Devolver ETH sobrante al sender
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0)
            CurrencyLibrary.NATIVE.transfer(msg.sender, ethBalance);
    }

    // Callback ejecutado por Pool Manager
    function unlockCallback(
        bytes calldata rawData
    ) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert CallerNotManager();
        CallbackData memory data = abi.decode(rawData, (CallbackData));

        // Ejecutar el swap
        BalanceDelta delta = manager.swap(data.key, data.params, data.hookData);

        // Obtener deltas después del swap
        int256 deltaAfter0 = manager.currencyDelta(
            address(this),
            data.key.currency0
        );
        int256 deltaAfter1 = manager.currencyDelta(
            address(this),
            data.key.currency1
        );

        // Settle tokens que debemos (deltas negativos)
        if (deltaAfter0 < 0) {
            data.key.currency0.settle(
                manager,
                data.sender,
                uint256(-deltaAfter0),
                false
            );
        }

        if (deltaAfter1 < 0) {
            data.key.currency1.settle(
                manager,
                data.sender,
                uint256(-deltaAfter1),
                false
            );
        }

        // Take tokens que recibimos (deltas positivos)
        if (deltaAfter0 > 0) {
            _take(
                data.key.currency0,
                data.settings.recipientAddress,
                uint256(deltaAfter0),
                data.settings.bridgeTokens
            );
        }

        if (deltaAfter1 > 0) {
            _take(
                data.key.currency1,
                data.settings.recipientAddress,
                uint256(deltaAfter1),
                data.settings.bridgeTokens
            );
        }

        return abi.encode(delta);
    }

    // Función interna para take + bridge opcional
    function _take(
        Currency currency,
        address recipient,
        uint256 amount,
        bool bridgeToOptimism
    ) internal {
        if (!bridgeToOptimism) {
            // Envío directo en L1
            currency.take(manager, recipient, amount, false);
        } else {
            // Take al router y luego bridge
            currency.take(manager, address(this), amount, false);

            if (currency.isNative()) {
                // Bridge ETH
                l1StandardBridge.depositETHTo{value: amount}(
                    recipient, 
                    0, 
                    ""
                );
            } else {
                // Bridge ERC20
                address l1Token = Currency.unwrap(currency);
                address l2Token = l1ToL2TokenAddresses[l1Token];

                IERC20Minimal(l1Token).approve(
                    address(l1StandardBridge),
                    amount
                );
                l1StandardBridge.depositERC20To(
                    l1Token,
                    l2Token,
                    recipient,
                    amount,
                    0,
                    ""
                );
            }
        }
    }

    // Necesario para recibir ETH del Pool Manager
    receive() external payable {}
}
```

## Análisis Técnico Profundo

### Patrones de Diseño

**1. Router Pattern**
```solidity
// EOA → Router → Pool Manager
function swap(...) external payable returns (BalanceDelta) {
    // Validaciones
    // Unlock Pool Manager
    // Callback execution
    // Cleanup
}
```

**2. Callback Pattern**
```solidity
function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
    // Decode data
    // Execute swap
    // Handle settlements
    // Return result
}
```

**3. External Integration Pattern**
```solidity
function _take(..., bool bridgeToOptimism) internal {
    if (!bridgeToOptimism) {
        // Direct transfer
    } else {
        // Take + external service call
    }
}
```

### Testing Comprehensivo

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, Vm} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {SwapAndBridgeOptimismRouter, IL1StandardBridge} from "../src/SwapAndBridgeOptimismRouter.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

interface IOUTbToken {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function faucet() external;
}

contract TestSwapAndBridgeOptimismRouter is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // Events del L1StandardBridge
    event ETHDepositInitiated(
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes extraData
    );

    event ERC20DepositInitiated(
        address indexed l1Token,
        address indexed l2Token,
        address indexed from,
        address to,
        uint256 amount,
        bytes extraData
    );

    uint256 sepoliaForkId = vm.createFork("https://rpc.sepolia.org/");
    SwapAndBridgeOptimismRouter poolSwapAndBridgeOptimism;

    // OUTb = Optimism Useless Token Bridged
    IOUTbToken OUTbL1Token = IOUTbToken(0x12608ff9dac79d8443F17A4d39D93317BAD026Aa);
    IOUTbToken OUTbL2Token = IOUTbToken(0x7c6b91D9Be155A6Db01f749217d76fF02A7227F2);

    IL1StandardBridge public constant l1StandardBridge =
        IL1StandardBridge(0xFBb0621E0B23b5478B630BD55a5f21f67730B0F1);

    function setUp() public {
        vm.selectFork(sepoliaForkId);
        vm.deal(address(this), 500 ether);

        deployFreshManagerAndRouters();
        poolSwapAndBridgeOptimism = new SwapAndBridgeOptimismRouter(
            manager,
            l1StandardBridge
        );

        // Setup tokens y pool
        OUTbL1Token.faucet();
        OUTbL1Token.approve(address(poolSwapAndBridgeOptimism), type(uint256).max);
        OUTbL1Token.approve(address(modifyLiquidityRouter), type(uint256).max);

        poolSwapAndBridgeOptimism.addL1ToL2TokenAddress(
            address(OUTbL1Token),
            address(OUTbL2Token)
        );

        (key, ) = initPool(
            CurrencyLibrary.NATIVE,
            Currency.wrap(address(OUTbL1Token)),
            IHooks(address(0)),
            3000,
            SQRT_PRICE_1_1,
            ZERO_BYTES
        );
        
        modifyLiquidityRouter.modifyLiquidity{value: 1 ether}(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 10 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function test_swapETHForOUTb_bridgeToOptimism() public {
        vm.expectEmit(true, true, true, false);
        emit ERC20DepositInitiated(
            address(OUTbL1Token),
            address(OUTbL2Token),
            address(poolSwapAndBridgeOptimism),
            address(this),
            0,
            ZERO_BYTES
        );

        poolSwapAndBridgeOptimism.swap{value: 0.001 ether}(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            SwapAndBridgeOptimismRouter.SwapSettings({
                bridgeTokens: true,
                recipientAddress: address(this)
            }),
            ZERO_BYTES
        );
    }

    function test_swapWithoutBridging() public {
        uint256 ethBalanceBefore = address(this).balance;
        uint256 OUTbBalanceBefore = OUTbL1Token.balanceOf(address(this));

        poolSwapAndBridgeOptimism.swap{value: 0.001 ether}(
            key,
            IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: -0.001 ether,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            SwapAndBridgeOptimismRouter.SwapSettings({
                bridgeTokens: false,
                recipientAddress: address(this)
            }),
            ZERO_BYTES
        );

        uint256 ethBalanceAfter = address(this).balance;
        uint256 OUTbBalanceAfter = OUTbL1Token.balanceOf(address(this));

        assertEq(ethBalanceBefore - ethBalanceAfter, 0.001 ether);
        assertGt(OUTbBalanceAfter, OUTbBalanceBefore);
    }
}
```

## Casos de Uso Avanzados

### 1. Multi-Chain Arbitrage Router
```solidity
contract MultiChainArbitrageRouter {
    struct ArbitrageParams {
        PoolKey sourceKey;
        uint256 targetChainId;
        address targetPool;
        uint256 minProfitBps;
    }

    function executeArbitrage(ArbitrageParams memory params) external {
        // 1. Swap en chain actual
        // 2. Bridge a target chain
        // 3. Validar profit threshold
        // 4. Execute o revert
    }
}
```

### 2. Yield Farming Router
```solidity
contract YieldFarmingRouter {
    function swapAndStake(
        PoolKey memory key,
        SwapParams memory params,
        address stakingContract,
        uint256 stakingDuration
    ) external {
        // 1. Swap tokens
        // 2. Stake en yield farm
        // 3. Setup auto-compound
    }
}
```

## Extensiones y Mejoras

### 1. Multi-Bridge Support
```solidity
mapping(uint256 chainId => address bridgeContract) public bridges;
mapping(address token => mapping(uint256 chainId => address)) public tokenMappings;

function addBridgeSupport(
    uint256 chainId,
    address bridgeContract,
    address[] memory l1Tokens,
    address[] memory remoteTokens
) external onlyOwner {
    bridges[chainId] = bridgeContract;
    for (uint i = 0; i < l1Tokens.length; i++) {
        tokenMappings[l1Tokens[i]][chainId] = remoteTokens[i];
    }
}
```

### 2. Dynamic Fee Optimization
```solidity
function calculateOptimalBridgeFee(
    address token,
    uint256 amount,
    uint256 targetChainId
) public view returns (uint256 fee) {
    // Analizar network congestion
    // Optimizar fee para tiempo vs costo
    uint256 baseFee = IBridge(bridges[targetChainId]).getBaseFee();
    uint256 congestionMultiplier = getNetworkCongestion(targetChainId);
    return baseFee * congestionMultiplier / 100;
}
```

### 3. Emergency Controls
```solidity
bool public emergencyPaused;
mapping(address => bool) public tokenPaused;

modifier notPaused() {
    require(!emergencyPaused, "Contract paused");
    _;
}

modifier tokenNotPaused(address token) {
    require(!tokenPaused[token], "Token paused");
    _;
}

function emergencyPause() external onlyOwner {
    emergencyPaused = true;
}

function pauseToken(address token) external onlyOwner {
    tokenPaused[token] = true;
}
```

## Comparación: Hook vs Router

| Aspecto | Hook | Router |
|---------|------|--------|
| **Coupling** | Tight con pool | Loose con pool |
| **External Calls** | Limitado | Ilimitado |
| **Gas Efficiency** | Muy alta | Alta |
| **Flexibility** | Limitada | Muy alta |
| **Complexity** | Media | Baja |
| **Use Cases** | Pool-specific logic | Workflow orchestration |

## Deployment y Testing

### Script de Deployment
```solidity
// script/DeployRouter.s.sol
contract DeployRouter is Script {
    function run() external {
        vm.startBroadcast();
        
        SwapAndBridgeOptimismRouter router = new SwapAndBridgeOptimismRouter(
            IPoolManager(0x...), // Pool Manager address
            IL1StandardBridge(0x...) // Bridge address
        );
        
        // Setup initial token mappings
        router.addL1ToL2TokenAddress(
            0x..., // USDC L1
            0x..., // USDC L2
        );
        
        vm.stopBroadcast();
    }
}
```

### Verificación Cross-Chain
```bash
# Deploy en Sepolia
forge script script/DeployRouter.s.sol --rpc-url sepolia --broadcast --verify

# Test bridge transaction
cast send $ROUTER_ADDRESS "swap(...)" --value 0.001ether --rpc-url sepolia

# Verificar en OP Sepolia después de ~1 minuto
cast balance $RECIPIENT_ADDRESS --rpc-url op-sepolia
```

## Consideraciones de Seguridad

### 1. Access Control
- Owner-only functions para agregar tokens soportados
- Validación de caller en callbacks
- Protección contra tokens no soportados

### 2. Reentrancy Protection
- Flash accounting del Pool Manager previene reentrancy
- Callbacks solo desde Pool Manager
- External calls después de state changes

### 3. Fund Safety
```solidity
function emergencyWithdraw(address token) external onlyOwner {
    if (token == address(0)) {
        payable(owner()).transfer(address(this).balance);
    } else {
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }
}
```

## Conclusiones y Próximos Pasos

### Key Takeaways

1. **Arquitectura Complementaria**: Routers y hooks resuelven problemas diferentes
2. **External Integration**: Routers son ideales para integrar servicios externos
3. **User Experience**: Una transaction para múltiples operaciones mejora UX
4. **Flexibility**: Routers permiten workflows complejos que hooks no pueden manejar

### Próximas Exploraciones

1. **Cross-Chain MEV**: Arbitrage opportunities across chains
2. **Intent-Based Routing**: User intents → optimal execution paths
3. **Gasless Transactions**: Meta-transactions para better UX
4. **Modular Architecture**: Plugin system para diferentes bridges/services

Esta sesión demuestra cómo los contratos de periferia pueden extender significativamente las capacidades de Uniswap v4, permitiendo workflows complejos que van más allá del simple trading.

## Referencias

- [Uniswap v4 Periphery](https://github.com/Uniswap/v4-periphery)
- [Optimism Bridge Documentation](https://docs.optimism.io/builders/app-developers/bridging/standard-bridge)
- [Router Implementation Example](https://github.com/haardikk21/v4-swap-bridge-router)
- [Cross-Chain Bridge Security](https://blog.li.fi/what-are-blockchain-bridges-and-how-can-we-classify-them-560dc6ec05fa) 