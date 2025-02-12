import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import deployLPToken from "../../deploy/LPToken"
import { compileContracts } from "../../utils/compileContracts"

task("deploy-lp-token", "Deploy the lp token").setAction(async taskArgs => {
    const hre: HardhatRuntimeEnvironment = require("hardhat")
    compileContracts({ quiet: true })

    await deployLPToken(hre)
})

export default {}
