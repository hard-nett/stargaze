#!/bin/bash

# Ensure Go is installed
if [[ ! -x "$(which go)" ]]; then
  echo "Go is not installed,"
  echo "ensure you have a working installation of go before trying again..."
  echo "https://golang.org/doc/install"
  exit 1
fi

GAIA_TAG="goz-phase-2"
CHAIN_DATA="$(pwd)/data"

rm -rf $CHAIN_DATA &> /dev/null
killall gaiad &> /dev/null
killall staked &> /dev/null

set -e

echo "Downloading and installing gaia tag $GAIA_TAG..."
(cd /tmp; \
curl -OL https://github.com/cosmos/gaia/archive/$GAIA_TAG.zip &> /dev/null; \
unzip -o $GAIA_TAG.zip &> /dev/null; \
cd gaia-$GAIA_TAG; \
make install &> /dev/null)

echo "Installing stakebird..."
make install &> /dev/null

chainid0=ibc0
chainid1=ibc1

echo "Generating configurations..."
mkdir -p $CHAIN_DATA && cd $CHAIN_DATA
echo -e "\n" | gaiad testnet -o $chainid0 --v 1 --chain-id $chainid0 --node-dir-prefix n --keyring-backend test &> /dev/null
echo -e "\n" | staked testnet -o $chainid1 --v 1 --chain-id $chainid1 --node-dir-prefix n --keyring-backend test

cfgpth="n0/gaiad/config/config.toml"
if [ "$(uname)" = "Linux" ]; then
  # TODO: Just index *some* specified tags, not all
  sed -i 's/index_all_keys = false/index_all_keys = true/g' $chainid0/$cfgpth
  
  # Set proper defaults and change ports
  sed -i 's/"leveldb"/"goleveldb"/g' $chainid0/$cfgpth
  
  # Make blocks run faster than normal
  sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid0/$cfgpth
  sed -i 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid0/$cfgpth
else
  # TODO: Just index *some* specified tags, not all
  sed -i '' 's/index_all_keys = false/index_all_keys = true/g' $chainid0/$cfgpth

  # Set proper defaults and change ports
  sed -i '' 's/"leveldb"/"goleveldb"/g' $chainid0/$cfgpth

  # Make blocks run faster than normal
  sed -i '' 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid0/$cfgpth
  sed -i '' 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid0/$cfgpth
fi

cfgpth="n0/staked/config/config.toml"
if [ "$(uname)" = "Linux" ]; then
  # TODO: Just index *some* specified tags, not all
  sed -i 's/index_all_keys = false/index_all_keys = true/g' $chainid1/$cfgpth
  
  # Set proper defaults and change ports
  sed -i 's/"leveldb"/"goleveldb"/g' $chainid1/$cfgpth
  sed -i 's#"tcp://0.0.0.0:26656"#"tcp://0.0.0.0:26556"#g' $chainid1/$cfgpth
  sed -i 's#"tcp://0.0.0.0:26657"#"tcp://0.0.0.0:26557"#g' $chainid1/$cfgpth
  sed -i 's#"localhost:6060"#"localhost:6061"#g' $chainid1/$cfgpth
  sed -i 's#"tcp://127.0.0.1:26658"#"tcp://127.0.0.1:26558"#g' $chainid1/$cfgpth
  
  # Make blocks run faster than normal
  sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid1/$cfgpth
  sed -i 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid1/$cfgpth
else
  # TODO: Just index *some* specified tags, not all
  sed -i '' 's/index_all_keys = false/index_all_keys = true/g' $chainid1/$cfgpth

  # Set proper defaults and change ports
  sed -i '' 's/"leveldb"/"goleveldb"/g' $chainid1/$cfgpth
  sed -i '' 's#"tcp://0.0.0.0:26656"#"tcp://0.0.0.0:26556"#g' $chainid1/$cfgpth
  sed -i '' 's#"tcp://0.0.0.0:26657"#"tcp://0.0.0.0:26557"#g' $chainid1/$cfgpth
  sed -i '' 's#"localhost:6060"#"localhost:6061"#g' $chainid1/$cfgpth
  sed -i '' 's#"tcp://127.0.0.1:26658"#"tcp://127.0.0.1:26558"#g' $chainid1/$cfgpth

  # Make blocks run faster than normal
  sed -i '' 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid1/$cfgpth
  sed -i '' 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid1/$cfgpth
fi

gclpth="n0/gaiacli/"
gaiacli config --home $chainid0/$gclpth chain-id $chainid0
gaiacli config --home $chainid0/$gclpth output json
gaiacli config --home $chainid0/$gclpth node http://localhost:26657

gclpth="n0/stakecli/"
stakecli config --home $chainid1/$gclpth chain-id $chainid1 &> /dev/null
stakecli config --home $chainid1/$gclpth output json &> /dev/null
stakecli config --home $chainid1/$gclpth node http://localhost:26557 &> /dev/null

echo "Starting chain instances..."
gaiad --home $CHAIN_DATA/$chainid0/n0/gaiad start --pruning=nothing > $chainid0.log 2>&1 &
staked --home $CHAIN_DATA/$chainid1/n0/staked start --pruning=nothing > $chainid1.log 2>&1 & 
