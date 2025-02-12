import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { compileContracts } from "../../utils/compileContracts"

task("deposit-to-pool", "Deposit to the pool").setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    compileContracts({ quiet: true })
})

export default {}
