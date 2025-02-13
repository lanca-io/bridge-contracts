export const RegistrationParamsAbi = [
	{
		"inputs": [
			{
				"components": [
                    { "internalType": "address", "name": "upkeepContract", "type": "address" },
                    { "internalType": "uint96", "name": "amount", "type": "uint96" },
                    { "internalType": "address", "name": "adminAddress", "type": "address" },
                    { "internalType": "uint32", "name": "gasLimit", "type": "uint32" },
                    { "internalType": "uint8", "name": "triggerType", "type": "uint8" },
                    { "internalType": "address", "name": "billingToken", "type": "address" },
                    { "internalType": "string", "name": "name", "type": "string" },
                    { "internalType": "bytes", "name": "encryptedEmail", "type": "bytes" },
                    { "internalType": "bytes", "name": "checkData", "type": "bytes" },
                    { "internalType": "bytes", "name": "triggerConfig", "type": "bytes" },
                    { "internalType": "bytes", "name": "offchainConfig", "type": "bytes" }
				],
				"internalType": "struct RegistrationParams",
				"name": "requestParams",
				"type": "tuple"
			}
		],
		"name": "registerUpkeep",
		"outputs": [
			{
				"internalType": "uint256",
				"name": "",
				"type": "uint256"
			}
		],
		"stateMutability": "nonpayable",
		"type": "function"
	}
]