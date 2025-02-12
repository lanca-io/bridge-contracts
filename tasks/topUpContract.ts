import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { compileContracts } from "../../utils/compileContracts"

task("top-up-contract", "Deploy the lp token").setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    compileContracts({ quiet: true })
})

export default {}
