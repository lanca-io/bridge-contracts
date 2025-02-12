import { task } from "hardhat/config"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { compileContracts } from "../../utils/compileContracts"

task("top-up-contract", "Deploy the lp token")
    .addParam("type", "Type of contract to top up")
    .setAction(async taskArgs => {
        const hre: HardhatRuntimeEnvironment = require("hardhat")
        compileContracts({ quiet: true })

        if (taskArgs.type === "parentPool") {
            console.log("Top up parentPool contract")
        } else if (taskArgs.type === "childPool") {
            console.log("Top up childPool contract")
        } else {
            console.log("Invalid contract type")
        }
    })

export default {}
