//V1
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./Pausable.sol";
import "./AccessControl.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";
import "./Math.sol";
import "./ISQFItem.sol";


contract SQFIFactory is Pausable, AccessControl {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    ISQFItem public SQFi;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    address public fee1;
    uint256 public amount1 = 10;

    event CraftSQFI(
        address owner,
        uint256 tokenId,
        address fee1,
        uint256 amount1
    );
    event UncraftSQFI(
        uint256 tokenId
    );
    event FeeChange(address currency, uint256 amount, bool enable);

    constructor(
        address _sqfi,
        address _fee1
    ) {
        SQFi = ISQFItem(_sqfi);
        fee1 = _fee1;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    function bytes32ToAmount16(bytes32 data)
        public
        pure
        returns (uint256[16] memory amount)
    {
        for (uint8 i = 0; i < 32; i++) {
            amount[i / 2] =
                amount[i / 2] +
                uint8(data[i]) *
                256**(i % 2 == 0 ? 1 : 0);
        }
    }
    function editSupportedFee(
        address _fee1,
        uint256 _amount1
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        fee1 = _fee1;
        amount1 = _amount1;
    }

    function createSQFI(
        string memory tokenURI_
    ) public whenNotPaused returns (uint256) {
        // if (amount1 > 0 && fee1 != address(0x0)) {
        //     IERC20(fee1).transferFrom(msg.sender, address(this), amount1);
        // }
        uint256 tokenId = SQFi.safeMint(
            msg.sender,
            tokenURI_
        );
        emit CraftSQFI(
            msg.sender,
            tokenId,
            fee1,
            amount1
        );
        return tokenId;
    }

    function uncraft(
        uint256 tokenId
    ) public virtual {
        SQFi.burn(tokenId);
        emit UncraftSQFI(tokenId);
    }

    function withdraw(address token, uint256 amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (token == address(0x0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }
    }
}