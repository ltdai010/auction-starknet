// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Auctions is Ownable {
    constructor() {}
    // ------- structs ------- //
    struct Auction {
        uint256 start_price;
        address highest_bidder;
        address coin_buy;
        address creator;
        bool ended;
    }
    // ------- structs ------- //
    
    // ------- var ------- //
    address constant public EMPTY_ADDRESS = 0x0000000000000000000000000000000000000000;
    // ------- var ------- //

    // ------- mapping ------- //
    // mapping contract sale and id to bidding data;
    mapping(bytes32 => Auction) private mapTokenToAuction;
    // mapping bidder address, contract sale and id to bid amount
    mapping(bytes32 => uint256) private mapBiddedAddress;

    // start an auction
    function start(address _contract_sale, uint256 _token_id, address _coin_buy, uint256 _start_price) external {
        bytes32 hashed = sha256(abi.encodePacked(_contract_sale, _token_id));
        IERC721 contractSale = IERC721(_contract_sale);
        // must be owner
        require(contractSale.ownerOf(_token_id) == msg.sender, "NOT_OWNED");
        // transfer to sale contract
        contractSale.transferFrom(msg.sender, address(this), _token_id);
        // write data to map
        mapTokenToAuction[hashed] = Auction(_start_price, EMPTY_ADDRESS, _coin_buy, msg.sender, false);
    }

    // bid
    function bid(address _contract_sale, uint256 _token_id, uint256 amount) external {
        // get auction data out
        bytes32 hashedAuction = sha256(abi.encodePacked(_contract_sale, _token_id));
        require(mapTokenToAuction[hashedAuction].creator != EMPTY_ADDRESS, "NOT_EXISTED");
        
        bytes32 hashedBidder = sha256(abi.encodePacked(_contract_sale, _token_id, msg.sender));

        // transfer to sale contract
        IERC20 contractCoinBuy = IERC20(mapTokenToAuction[hashedAuction].coin_buy);

        contractCoinBuy.transferFrom(msg.sender, address(this), amount);
        mapBiddedAddress[hashedBidder] = mapBiddedAddress[hashedBidder] + amount;
        // must be higher than current highest bid
        bytes32 highestBidderHash = sha256(abi.encodePacked(_contract_sale, _token_id, mapTokenToAuction[hashedAuction].highest_bidder));
        require(mapBiddedAddress[highestBidderHash] < mapBiddedAddress[hashedBidder], "BID_TOO_LOW");
        mapTokenToAuction[hashedAuction].highest_bidder = msg.sender;
    }

    // return auction info
    function auctionInfo(address _contract_sale, uint256 _token_id) external view returns(
        uint256 start_price,
        address highest_bidder,
        address coin_buy,
        address creator,
        bool ended
    ) {
        bytes32 hashed = sha256(abi.encodePacked(_contract_sale, _token_id));
        start_price = mapTokenToAuction[hashed].start_price;
        highest_bidder = mapTokenToAuction[hashed].highest_bidder;
        coin_buy = mapTokenToAuction[hashed].coin_buy;
        creator = mapTokenToAuction[hashed].creator;
        ended = mapTokenToAuction[hashed].ended;
    }


    function biddedBalance(address _contract_sale, uint256 _token_id, address _bidder) external view returns(uint256 bidded) {
        bytes32 hashed = sha256(abi.encodePacked(_contract_sale, _token_id, _bidder));
        bidded = mapBiddedAddress[hashed];
    }

    // withdraw back when bidding is end
    function withdraw(address _contract_sale, uint256 _token_id) external {
        bytes32 hashedAuction = sha256(abi.encodePacked(_contract_sale, _token_id));
        bytes32 hashedBidder = sha256(abi.encodePacked(_contract_sale, _token_id, msg.sender));
        require(mapTokenToAuction[hashedAuction].ended == true, "NOT_END_YET");
        IERC20 contractCoinBuy = IERC20(mapTokenToAuction[hashedAuction].coin_buy);
        contractCoinBuy.transferFrom(address(this), msg.sender, mapBiddedAddress[hashedBidder]);
        mapBiddedAddress[hashedBidder] = 0;
    }

    // finish auction, only can call by creator to force stop auction. Asset will deliver to the highest bidded account
    function finish(address _contract_sale, uint256 _token_id) external {
        bytes32 hashed = sha256(abi.encodePacked(_contract_sale, _token_id));
        Auction memory auction;
        auction = mapTokenToAuction[hashed];
        require(auction.creator == msg.sender || this.owner() == msg.sender, "NO PERMISSION");
        IERC721 contractSale = IERC721(_contract_sale);
        // transfer asset
        if (auction.highest_bidder == EMPTY_ADDRESS) {
            // if highest bidded is empty, send back to creator
            contractSale.transferFrom(address(this), auction.creator, _token_id);
        } else {
            IERC20 contractCoin = IERC20(auction.coin_buy);
            // if exist bidder, transfer to bidder
            contractSale.transferFrom(address(this), auction.highest_bidder, _token_id);
            bytes32 hashedBidder = sha256(abi.encodePacked(_contract_sale, _token_id, auction.highest_bidder));
            uint256 amount = mapBiddedAddress[hashedBidder];
            mapBiddedAddress[hashedBidder] = 0;
            // transfer coin buy to creator
            contractCoin.transfer(auction.creator, amount);
        }
        auction.ended = true;
    }
}
