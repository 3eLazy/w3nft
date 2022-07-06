// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EIP712Signing is Ownable {
    using ECDSA for bytes32;

    // The key used to sign signatures.
    // We will check to ensure that the key that signed the signature
    // is this one that we expect.
    address private signingKey = address(0);

    // Domain Separator is the EIP-712 defined structure that defines what contract
    // and chain these signatures can be used for.  This ensures people can't take
    // a signature used to mint on one contract and use it for another, or a signature
    // from testnet to replay on mainnet.
    // It has to be created in the constructor so we can dynamically grab the chainId.
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#definition-of-domainseparator
    bytes32 private DOMAIN_SEPARATOR;

    // The typehash for the data type specified in the structured data
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-712.md#rationale-for-typehash
    // This should match whats in the client side signing code
    bytes32 private constant MINTER_TYPEHASH =
        keccak256("Minter(address wallet)");

    constructor() {
        // This should match whats in the client side signing code
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                // This should match the domain you set in your client side signing.
                keccak256(bytes("SignedData")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function setSigningAddress(address newSigningKey)
        external
        onlyOwner
    {
        signingKey = newSigningKey;
    }

    // modifier requiresSigned(bytes calldata signature) {
    //     require(signingKey != address(0), "Signed not enabled");
    //     require(
    //         getEIP712RecoverAddress(signature) == signingKey,
    //         "Not Signed"
    //     );
    //     _;
    // }

    function isEIP712Signed(bytes calldata signature)
        public
        view
        returns (bool)
    {
        require(signingKey != address(0), "Signed not enabled");
        return getEIP712Recover(signature) == signingKey;
    }

    function getEIP712Recover(bytes calldata signature)
        internal
        view
        returns (address)
    {
        // Verify EIP-712 signature by recreating the data structure
        // that we signed on the client side, and then using that to recover
        // the address that signed the signature for this data.
        // Signature begin with \x19\x01, see: https://eips.ethereum.org/EIPS/eip-712
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(MINTER_TYPEHASH, msg.sender))
            )
        );

        // Use the recover method to see what address was used to create
        // the signature on this data.
        // Note that if the digest doesn't exactly match what was signed we'll
        // get a random recovered address.
        return digest.recover(signature);
    }
}