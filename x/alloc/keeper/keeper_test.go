package keeper_test

import (
	"testing"
	"time"

	sdk "github.com/cosmos/cosmos-sdk/types"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"
	bankkeeper "github.com/cosmos/cosmos-sdk/x/bank/keeper"
	minttypes "github.com/cosmos/cosmos-sdk/x/mint/types"
	"github.com/public-awesome/stargaze/app"
	"github.com/public-awesome/stargaze/testutil/simapp"
	"github.com/public-awesome/stargaze/x/alloc/types"
	"github.com/stretchr/testify/suite"
	tmproto "github.com/tendermint/tendermint/proto/tendermint/types"
)

type KeeperTestSuite struct {
	suite.Suite
	ctx sdk.Context
	app *app.App
}

func (suite *KeeperTestSuite) SetupTest() {
	suite.app = simapp.New(suite.T().TempDir())
	suite.ctx = suite.app.BaseApp.NewContext(false, tmproto.Header{Height: 1, ChainID: "stargaze-1", Time: time.Now().UTC()})
	suite.app.AllocKeeper.SetParams(suite.ctx, types.DefaultParams())

}

func TestKeeperTestSuite(t *testing.T) {
	suite.Run(t, new(KeeperTestSuite))
}

func FundAccount(bankKeeper bankkeeper.Keeper, ctx sdk.Context, addr sdk.AccAddress, amounts sdk.Coins) error {
	if err := bankKeeper.MintCoins(ctx, minttypes.ModuleName, amounts); err != nil {
		return err
	}
	return bankKeeper.SendCoinsFromModuleToAccount(ctx, minttypes.ModuleName, addr, amounts)
}

func FundModuleAccount(bankKeeper bankkeeper.Keeper, ctx sdk.Context, recipientMod string, amounts sdk.Coins) error {
	if err := bankKeeper.MintCoins(ctx, minttypes.ModuleName, amounts); err != nil {
		return err
	}
	return bankKeeper.SendCoinsFromModuleToModule(ctx, minttypes.ModuleName, recipientMod, amounts)
}

func (suite *KeeperTestSuite) TestDistributionToDAOAndDevs() {
	suite.SetupTest()

	denom := suite.app.StakingKeeper.BondDenom(suite.ctx)
	allocKeeper := suite.app.AllocKeeper
	params := suite.app.AllocKeeper.GetParams(suite.ctx)
	devRewardsReceiver := sdk.AccAddress([]byte("addr1---------------"))
	params.DistributionProportions.DaoRewards = sdk.NewDecWithPrec(40, 2)
	params.DistributionProportions.DeveloperRewards = sdk.NewDecWithPrec(10, 2)
	params.WeightedDeveloperRewardsReceivers = []types.WeightedAddress{
		{
			Address: devRewardsReceiver.String(),
			Weight:  sdk.NewDec(1),
		},
	}
	suite.app.AllocKeeper.SetParams(suite.ctx, params)

	feePool := suite.app.DistrKeeper.GetFeePool(suite.ctx)
	feeCollector := suite.app.AccountKeeper.GetModuleAddress(authtypes.FeeCollectorName)
	suite.Equal(
		"0",
		suite.app.BankKeeper.GetAllBalances(suite.ctx, feeCollector).AmountOf(denom).String())
	suite.Equal(
		sdk.NewDec(0),
		feePool.CommunityPool.AmountOf(denom))

	mintCoin := sdk.NewCoin(denom, sdk.NewInt(100000))
	mintCoins := sdk.Coins{mintCoin}
	feeCollectorAccount := suite.app.AccountKeeper.GetModuleAccount(suite.ctx, authtypes.FeeCollectorName)
	suite.Require().NotNil(feeCollectorAccount)

	suite.Require().NoError(FundModuleAccount(suite.app.BankKeeper, suite.ctx, feeCollectorAccount.GetName(), mintCoins))

	feeCollector = suite.app.AccountKeeper.GetModuleAddress(authtypes.FeeCollectorName)
	suite.Equal(
		mintCoin.Amount.String(),
		suite.app.BankKeeper.GetAllBalances(suite.ctx, feeCollector).AmountOf(denom).String())

	suite.Equal(
		sdk.NewDec(0),
		feePool.CommunityPool.AmountOf(denom))

	allocKeeper.DistributeInflation(suite.ctx)

	feeCollector = suite.app.AccountKeeper.GetModuleAddress(authtypes.FeeCollectorName)
	feePool = suite.app.DistrKeeper.GetFeePool(suite.ctx)
	modulePortion := params.DistributionProportions.DaoRewards.
		Add(params.DistributionProportions.DeveloperRewards)
	suite.Equal(
		mintCoin.Amount.ToDec().Mul(modulePortion).RoundInt().String(),
		suite.app.BankKeeper.GetAllBalances(suite.ctx, feeCollector).AmountOf(denom).String())
	suite.Equal(
		mintCoin.Amount.ToDec().Mul(params.DistributionProportions.DeveloperRewards).TruncateInt(),
		suite.app.BankKeeper.GetBalance(suite.ctx, devRewardsReceiver, denom).Amount)
	// since the DAO is not setup yet, funds go into the communtiy pool
	suite.Equal(
		mintCoin.Amount.ToDec().Mul(params.DistributionProportions.DaoRewards),
		feePool.CommunityPool.AmountOf(denom))
}