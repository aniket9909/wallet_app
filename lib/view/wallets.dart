import 'package:ewallet/core/utils/color_extension.dart';
import 'package:ewallet/core/widgets/CustomeText.dart';
import 'package:ewallet/core/widgets/CustomeWalletCard.dart';
import 'package:ewallet/models/wallet_type_master_model.dart';
import 'package:ewallet/viewmodels/all_wallet_view_model.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

class AllWallets extends StatelessWidget {
  AllWallets({super.key});
  AllWalletViewModel allWalletViewModel =
      AllWalletViewModel(); // Initialize the view model

  @override
  Widget build(BuildContext context) {
    final allWalletsVm = Provider.of<AllWalletViewModel>(context);
    return Scaffold(
        appBar: AppBar(
          title: CommonText(
            text: "My Wallets",
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
          actions: [
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.circlePlus,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {},
            ),
          ],
          centerTitle: true,
          backgroundColor: context.customColors.primaryColor,
        ),
        body: Container(
          color: context.customColors.primaryColor,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: allWalletsVm.wallets.length +
                      1, // Replace with your wallet count
                  itemBuilder: (context, index) {
                    if (index == allWalletsVm.wallets.length) {
                      return Padding(
                        padding: EdgeInsets.all(10),
                        child: CustomeWalletCard(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context)
                                        .viewInsets
                                        .bottom,
                                    left: 16,
                                    right: 16,
                                    top: 24,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CommonText(
                                        text: "Add New Wallet",
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      SizedBox(height: 16),
                                      TextField(
                                        controller: allWalletViewModel
                                            .walletAmountController,
                                        decoration: InputDecoration(
                                          labelText: "Wallet Amount",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      DropdownButtonFormField<TypeMasterModel>(
                                        decoration: InputDecoration(
                                          labelText: "Wallet Type",
                                          border: OutlineInputBorder(),
                                        ),
                                        items: allWalletsVm.walletType.map<
                                                DropdownMenuItem<
                                                    TypeMasterModel>>(
                                            (dynamic type) {
                                          return DropdownMenuItem<
                                              TypeMasterModel>(
                                            value: type,
                                            child: Text(type.name),
                                          );
                                        }).toList(),
                                        onChanged: (typeValue) {
                                          allWalletViewModel.walletTypeController
                                              .text = typeValue!.value.toString();
                                          // Handle wallet type selection
                                        },
                                      ),
                                      SizedBox(height: 24),
                                      ElevatedButton(
                                        onPressed: () {
                                          allWalletViewModel.addWallet();
                                          Navigator.of(context).pop();
                                        },
                                        child: Text("Add Wallet"),
                                      ),
                                      SizedBox(height: 16),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          walletName: 'Add New Wallet',
                          walletBalance: '',
                          leadingImage: 'assets/images/wallet.png',
                          backgroundColor: Color(0xff404CB2),
                          textColor: Colors.white,
                        ),
                      );
                    } else {
                      return Padding(
                        padding: EdgeInsets.all(10),
                        child: CustomeWalletCard(
                          onTap: () {
                            // Handle wallet tap action
                          },
                          walletName: '${allWalletsVm.wallets[index].name}',
                          walletBalance: '${allWalletsVm.wallets[index].balance}',
                          leadingImage: 'assets/logo/ewallet.png',
                          backgroundColor: Colors.white,
                          textColor: context.customColors.primaryColor,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ));
  }
}
