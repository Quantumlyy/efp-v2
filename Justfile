# List all recipes
default:
    @just --list

# === Project config ===

circuit := "encrypt"
circuit_dir := "circuits/" + circuit

# === Toolchain (or use `mise run bootstrap`) ===

# Install/update foundry, nargo, bb
install-tools:
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
    noirup
    curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/refs/heads/next/barretenberg/bbup/install | bash
    bbup

# Install Solidity dependencies
deps:
    forge install

# === Circuit pipeline ===

# Scaffold Prover.toml from the circuit's main() signature
scaffold:
    cd {{circuit_dir}} && nargo check
    @echo "Edit {{circuit_dir}}/Prover.toml with your inputs, then run 'just prove'"

# Compile the Noir circuit -> ./target/{{circuit}}.json
compile:
    cd {{circuit_dir}} && nargo compile

# Generate verification key (depends on compile)
vk: compile
    cd {{circuit_dir}} && bb write_vk \
        -b ./target/{{circuit}}.json \
        -o ./target \
        --oracle_hash keccak

# Generate the Solidity verifier and copy it into src/
verifier: vk
    cd {{circuit_dir}} && bb write_solidity_verifier \
        -k ./target/vk \
        -o ./target/Verifier.sol
    @mkdir -p src
    @cp {{circuit_dir}}/target/Verifier.sol src/Verifier.sol
    @echo "Verifier.sol copied to src/"

# Generate witness + proof + public inputs (uses Prover.toml in the circuit dir)
prove: compile
    @test -f {{circuit_dir}}/Prover.toml || { echo "Prover.toml missing — run 'just scaffold' first"; exit 1; }
    cd {{circuit_dir}} && nargo execute witness
    cd {{circuit_dir}} && bb prove \
        -b ./target/{{circuit}}.json \
        -w ./target/witness.gz \
        -o ./target \
        --oracle_hash keccak \
        --output_format bytes_and_fields
    @mkdir -p test/fixtures
    @cp {{circuit_dir}}/target/proof test/fixtures/proof
    @cp {{circuit_dir}}/target/public_inputs test/fixtures/public_inputs
    @echo "proof + public_inputs copied to test/fixtures/"

# Full pipeline: compile -> vk -> verifier -> prove
build: verifier prove

# Hash of the compiled circuit (use in CI to detect circuit/verifier drift)
circuit-hash:
    @sha256sum {{circuit_dir}}/target/{{circuit}}.json | cut -d' ' -f1

# === Foundry ===

# Run tests (verifier exceeds EIP-170, hence --code-size-limit)
test:
    forge test --code-size-limit 50000 -vv

# Run tests with FFI enabled (for proofs generated on the fly)
test-ffi:
    forge test --ffi --code-size-limit 50000 -vv

# Format Solidity and Noir sources
fmt:
    forge fmt
    cd {{circuit_dir}} && nargo fmt

# === Cleanup ===

clean:
    rm -rf {{circuit_dir}}/target
    rm -rf test/fixtures/proof test/fixtures/public_inputs
    forge clean
