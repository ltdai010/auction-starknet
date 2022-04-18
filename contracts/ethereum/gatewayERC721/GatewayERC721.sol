// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./IStarknetCore.sol";

contract GatewayERC721 {
    address public initialEndpointGatewaySetter;
    uint256 public endpointGateway;
    IStarknetCore public starknetCore;
    uint256 constant ENDPOINT_GATEWAY_SELECTOR = 1738423374452994793145864788013146788518531877200292826651981332061687045062;
    uint256 constant BRIDGE_MODE_DEPOSIT = 0;
    uint256 constant BRIDGE_MODE_WITHDRAW = 1;

    // Bootstrap
    constructor(address _starknetCore) {
        require(
            _starknetCore != address(0),
            "Gateway/invalid-starknet-core-address"
        );
    
        starknetCore = IStarknetCore(_starknetCore);
        initialEndpointGatewaySetter = msg.sender;
    }

    function setEndpointGateway(uint256 _endpointGateway) external {
        require(
            msg.sender == initialEndpointGatewaySetter,
            "Gateway/unauthorized"
        );
        require(endpointGateway == 0, "Gateway/endpoint-gateway-already-set");
        endpointGateway = _endpointGateway;
    }

    // Utils
    function addressToUint(address value)
        internal
        pure
        returns (uint256 convertedValue)
    {
        convertedValue = uint256(uint160(address(value)));
    }

    // Bridging to Starknet
    function bridgeToStarknet(
        IERC721 _l1TokenContract,
        uint256 _l2TokenContract,
        uint256 _tokenId,
        uint256 _account
    ) external {
        uint256[] memory payload = new uint256[](4);
        require(endpointGateway != 0, "Gateway unset");
    
        // optimistic transfer, should revert if no approved or not owner
        _l1TokenContract.transferFrom(msg.sender, address(this), _tokenId);

        // build deposit message payload
        payload[0] = _account;
        payload[1] = addressToUint(address(_l1TokenContract));
        payload[2] = _l2TokenContract;
        payload[3] = _tokenId;

        // send message
        starknetCore.sendMessageToL2(
            endpointGateway,
            ENDPOINT_GATEWAY_SELECTOR,
            payload
        );
    }

    // Bridging back from Starknet
    function bridgeFromStarknet(
        IERC721 _l1TokenContract,
        uint256 _l2TokenContract,
        uint256 _tokenId
    ) external {
        uint256[] memory payload = new uint256[](5);
        require(endpointGateway != 0, "Gateway unset");

        // build withdraw message payload
        payload[0] = BRIDGE_MODE_WITHDRAW;
        payload[1] = addressToUint(msg.sender);
        payload[2] = addressToUint(address(_l1TokenContract));
        payload[3] = _l2TokenContract;
        payload[4] = _tokenId;

        // consum withdraw message
        starknetCore.consumeMessageFromL2(endpointGateway, payload);

        // optimistic transfer, should revert if gateway is not token owner
        _l1TokenContract.transferFrom(address(this), msg.sender, _tokenId);
    }
}
