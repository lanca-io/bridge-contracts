import { task, types } from "hardhat/config"
import log, { err } from "../../utils/log"
import fs from "fs"
import path from "path"
import vm from "vm"

export const pathToScript = [__dirname, "../../", "clf"]

function checkFileAccessibility(filePath) {
    if (!fs.existsSync(filePath)) {
        err(`The file ${filePath} does not exist.`, "checkFileAccessibility")
        process.exit(1)
    }
}

function validateSyntax(content, filePath) {
    const ignoredErrors = [
        "Cannot use import statement outside a module",
        "await is only valid in async functions and the top level bodies of modules",
    ]
    try {
        new vm.Script(content)
    } catch (error) {
        if (ignoredErrors.includes(error.message)) return

        err(`Syntax error in file ${filePath}: ${error}`, "validateSyntax")
        process.exit(1)
    }
}

function replaceEnvironmentVariables(content) {
    let missingVariable = false
    const updatedContent = content.replace(/'\${(.*?)}'/g, (match, variable) => {
        const value = process.env[variable]

        if (value === undefined) {
            err(`Environment variable ${variable} is missing.`, "replaceEnvironmentVariables")
            process.exit(1)
        }
        return `'${value}'`
    })

    if (missingVariable) {
        err("One or more environment variables are missing.", "replaceEnvironmentVariables")
        process.exit(1)
    }
    return updatedContent
}

function saveProcessedFile(content: string, outputPath: string, quiet: boolean): void {
    const outputDir = path.join(...pathToScript, `dist/`)
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true })
    }
    const outputFile = path.join(outputDir, path.basename(outputPath))
    fs.writeFileSync(outputFile, content, "utf8")
    if (!quiet) log(`Saved to ${outputFile}`, "saveProcessedFile")
}

function cleanupFile(content) {
    const marker = "/*BUILD_REMOVES_EVERYTHING_ABOVE_THIS_LINE*/"
    const index = content.indexOf(marker)
    if (index !== -1) content = content.substring(index + marker.length)
    return content
        .replace(/^\s*\/\/.*$/gm, "") // Remove single-line comments that might be indented
        .replace(/\/\*[\s\S]*?\*\//g, "") // Remove multi-line comments
        .replace(/^\s*[\r\n]/gm, "") // Remove empty lines
}

function minifyFile(content) {
    return content
        .replace(/\n/g, " ")
        .replace(/\t/g, " ")
        .replace(/\s\s+/g, " ")
        .replace(/;\s*/g, ";")
        .replace(/\s*([=()+\-*\/{};,:<>])\s*/g, "$1")
}

function buildClfJsTask(fileToBuild: string, quiet: boolean): void {
    if (!fileToBuild) {
        err("Path to Functions script file is required.", "buildScript")
        return
    }

    checkFileAccessibility(fileToBuild)

    try {
        let fileContent = fs.readFileSync(fileToBuild, "utf8")
        // validateSyntax(fileContent, fileToBuild)

        fileContent = replaceEnvironmentVariables(fileContent)
        const cleanedUpFile = cleanupFile(fileContent)
        const minifiedFile = minifyFile(cleanedUpFile)

        saveProcessedFile(cleanedUpFile, fileToBuild, quiet)
        saveProcessedFile(minifiedFile, fileToBuild.replace(".js", ".min.js"), quiet)
        // validateSyntax(cleanedUpFile, fileToBuild)
        // validateSyntax(minifiedFile, fileToBuild)
    } catch (error) {
        err(`Error processing file ${fileToBuild}: ${error}`, "buildScript")
        process.exit(1)
    }
}
export async function buildScript(all: boolean, file: string | undefined, quiet: boolean): Promise<void> {
    if (all) {
        const paths = ["src", "src"]

        for (const relativePath of paths) {
            const fullPath = path.join(...pathToScript, relativePath)
            if (fs.existsSync(fullPath)) {
                const files = fs.readdirSync(fullPath)

                for (const scriptFile of files) {
                    if (scriptFile.endsWith(".js")) {
                        const fileToBuild = path.join(fullPath, scriptFile)
                        buildClfJsTask(fileToBuild, quiet)
                    }
                }
            } else {
                err(`Directory does not exist: ${fullPath}`, "runBuildScript")
            }
        }
        return
    }

    if (file) {
        const fileToBuild = path.join(...pathToScript, "src", file)
        buildClfJsTask(fileToBuild, quiet)
    } else {
        err("No file specified.", "runBuildScript", quiet)
        process.exit(1)
    }
}

// @notice Replaces environment variables in a file and saves the result to a dist folder.
task("clf-build-js", "Builds the JavaScript source code")
    .addFlag("all", "Build all scripts")
    .addOptionalParam("file", "Path to Functions script file", undefined, types.string)
    .addFlag("quiet", "Suppress console output")
    .setAction(async taskArgs => {
        const all = taskArgs.all || false
        const file = taskArgs.file
        const quiet = taskArgs.quiet || false

        await buildScript(all, file, quiet)
    })

export default {}
