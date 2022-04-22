//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Pausable.sol";
import "./AccessControl.sol";
import "./IERC721.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";

contract Marketplace is Pausable, AccessControl {
    using SafeERC20 for IERC20;
    bytes32 public constant MARKET_CONFIG = keccak256("MARKET_CONFIG");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public minTime = 0;
    address payable public owner;
    mapping(address => bool) public supportedNFT;
    struct Currency {
        uint256 fee;
        uint256 minNextBid;
        bool status;
    }
    mapping(address => Currency) public supportedCurrency;
    struct Order {
        uint256 nftId;
        uint256 timeEnd;
        uint256 currentPrice;
        uint256 spotPrice;
        address nftContract;
        address currency;
        address lastBid;
        address saler;
        bool isEnd;
    }
    Order[] public orders;

    event OrderCreate(
        uint256 orderId,
        address contractNft,
        address currency,
        address creator,
        uint256 timestamp,
        uint256 nftId,
        uint256 timeEnd,
        uint256 currentPrice,
        uint256 spotPrice
    );
    event FeeChange(uint256 newFee);
    event OrderCancel(uint256 orderId, uint256 timestamp);
    event Bid(
        address bidder,
        uint256 timestamp,
        uint256 orderId,
        uint256 price
    );
    event OrderConfirmed(
        uint256 orderId,
        address buyer,
        uint256 price,
        uint256 fee,
        uint256 timestamp
    );
    event EditCurrency(address token, uint256 fee, bool status);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MARKET_CONFIG, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        owner = payable(msg.sender);
    }

    function editSupportedCurrency(
        address token,
        uint256 fee,
        uint256 minNextBid,
        bool status
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedCurrency[token] = Currency(fee, minNextBid, status);
        emit EditCurrency(token, fee, status);
    }

    function addSupportedNFT(address _nftAddress)
        public
        onlyRole(MARKET_CONFIG)
    {
        supportedNFT[_nftAddress] = true;
    }

    function removeSupportedNFT(address _nftAddress)
        public
        onlyRole(MARKET_CONFIG)
    {
        supportedNFT[_nftAddress] = false;
    }

    function setMinTime(uint256 _time) public onlyRole(MARKET_CONFIG) {
        minTime = _time;
    }

    function createOrder(
        address contractNft,
        address currency,
        uint256 nftId,
        uint256 timeEnd,
        uint256 initPrice,
        uint256 spotPrice
    ) public whenNotPaused {
        require(supportedNFT[contractNft], "NFT must be supported");
        require(
            supportedCurrency[currency].status,
            "Currency must be supported"
        );
        require(
            IERC721(contractNft).ownerOf(nftId) == msg.sender,
            "Must be owner of NFT"
        );
        require(initPrice > 0, "Price invalid");
        require(spotPrice >= initPrice || spotPrice == 0, "Spot price invalid");
        require(timeEnd >= minTime + block.timestamp, "TimeEnd is invalid");
        IERC721(contractNft).transferFrom(msg.sender, address(this), nftId);
        orders.push(
            Order(
                nftId,
                timeEnd,
                initPrice,
                spotPrice,
                contractNft,
                currency,
                address(0x0),
                msg.sender,
                false
            )
        );
        emit OrderCreate(
            orders.length - 1,
            contractNft,
            currency,
            msg.sender,
            block.timestamp,
            nftId,
            timeEnd,
            initPrice,
            spotPrice
        );
    }

    function cancelOrder(uint256 orderId) public whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        require(order.saler == msg.sender, "Must be owner order");
        require(order.lastBid == address(0x0), "Must not have bider");
        require(!order.isEnd, "Must be not ended");
        order.isEnd = true;
        IERC721(order.nftContract).transferFrom(
            address(this),
            msg.sender,
            order.nftId
        );
        emit OrderCancel(orderId, block.timestamp);
    }

    function bid(uint256 orderId, uint256 amount) public payable whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        Currency memory currency = supportedCurrency[order.currency];
        if (order.currency == address(0x0)) {
            amount = msg.value;
        } else {
            require(msg.value == 0, "Invalid value");
            IERC20(order.currency).safeTransferFrom(
                msg.sender,
                address(this),
                amount
            );
        }
        require(!order.isEnd, "Order ended");
        require(order.timeEnd > block.timestamp, "Bid time ended");
        require(
            (order.currentPrice + currency.minNextBid <= amount ||
                (order.spotPrice != 0 && amount == order.spotPrice)),
            "Invalid bid amount"
        );
        if (order.lastBid != address(0x0))
            transfer(order.currency, order.lastBid, order.currentPrice);
        if (order.spotPrice != 0 && amount >= order.spotPrice) {
            transfer(
                order.currency,
                order.saler,
                (order.spotPrice * (100 - currency.fee)) / 100
            );
            if (amount > order.spotPrice) {
                transfer(order.currency, msg.sender, order.spotPrice - amount);
            }
            order.lastBid = msg.sender;
            order.currentPrice = order.spotPrice;
            order.isEnd = true;
            IERC721(order.nftContract).transferFrom(
                address(this),
                msg.sender,
                order.nftId
            );
            emit OrderConfirmed(
                orderId,
                msg.sender,
                order.spotPrice,
                (order.spotPrice * currency.fee) / 100,
                block.timestamp
            );
        } else {
            order.lastBid = msg.sender;
            order.currentPrice = amount;
            emit Bid(msg.sender, block.timestamp, orderId, amount);
        }
    }

    function approveSold(uint256 orderId) public whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        Currency memory currency = supportedCurrency[order.currency];
        require(order.saler == msg.sender, "Must be owner");
        require(
            !order.isEnd && order.lastBid != address(0x0),
            "Must be can claim"
        );
        order.isEnd = true;
        IERC721(order.nftContract).transferFrom(
            address(this),
            order.lastBid,
            order.nftId
        );
        transfer(
            order.currency,
            order.saler,
            (order.currentPrice * (100 - currency.fee)) / 100
        );
        emit OrderConfirmed(
            orderId,
            order.lastBid,
            order.currentPrice,
            (order.currentPrice * (currency.fee)) / 100,
            block.timestamp
        );
    }

    function claim(uint256 orderId) public whenNotPaused {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        Currency memory currency = supportedCurrency[order.currency];
        require(
            order.timeEnd < block.timestamp &&
                !order.isEnd &&
                order.lastBid != address(0x0),
            "Must be can claim"
        );
        order.isEnd = true;
        IERC721(order.nftContract).transferFrom(
            address(this),
            order.lastBid,
            order.nftId
        );
        transfer(
            order.currency,
            order.saler,
            (order.currentPrice * (100 - currency.fee)) / 100
        );
        emit OrderConfirmed(
            orderId,
            order.lastBid,
            order.currentPrice,
            (order.currentPrice * (currency.fee)) / 100,
            block.timestamp
        );
    }

    function transfer(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        if (token == address(0x0)) {
            payable(recipient).transfer(amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    function adminCancelOrder(uint256 orderId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(orderId < orders.length, "Order ID invalid");
        Order storage order = orders[orderId];
        require(order.lastBid == address(0x0), "Must not have bider");
        require(!order.isEnd, "Must be not ended");
        order.isEnd = true;
        IERC721(order.nftContract).transferFrom(
            address(this),
            order.saler,
            order.nftId
        );
        emit OrderCancel(orderId, block.timestamp);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();     
    }

    function withdraw(address token, uint256 amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (token == address(0x0)) {
            payable(owner).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner, amount);
        }
    }
}