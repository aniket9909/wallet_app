import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ewallet/core/widgets/CUstomerButton.dart';
import 'package:ewallet/core/widgets/CustomeText.dart';
import 'package:ewallet/core/utils/color_extension.dart';

import '../viewmodels/home_view_model.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  void initState() {
    super.initState();
    Provider.of<DashboardViewModel>(context, listen: false).listenToExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<DashboardViewModel>(context);
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.person_pin),
        title: Center(child: Text("All wallets")),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.calendar_month),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showAddwalletDialog(vm);
        },
        child: Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: [
              Container(
                color: Color(0xff243972),
                padding: EdgeInsets.fromLTRB(20, 20, 20, 80),
                child: Center(
                  child: Column(
                    children: [
                      CommonText(
                        text: "Total Amount",
                        color: context.customColors.textColor,
                      ),
                      CommonText(
                        text: "${vm.totalAmount}",
                        color: context.customColors.textColor,
                        fontSize: 40,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                child: Column(
                  children: [
                    Container(
                      margin: EdgeInsets.all(10),
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                // padding: EdgeInsets.symmetric(
                                //     horizontal: 16, vertical: 8),
                                // decoration: BoxDecoration(
                                //   color: Colors.grey[200],
                                //   borderRadius: BorderRadius.circular(60),
                                // ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: vm.selectedPeriod,
                                    items: [
                                      DropdownMenuItem(
                                        value: "this_week",
                                        child: CommonText(
                                          text: "This week",
                                          color:
                                              context.customColors.buttonColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: "this_month",
                                        child: CommonText(
                                          text: "This month",
                                          color:
                                              context.customColors.buttonColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: "last_week",
                                        child: CommonText(
                                          text: "Last week",
                                          color:
                                              context.customColors.buttonColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: "last_month",
                                        child: CommonText(
                                          text: "Last month",
                                          color:
                                              context.customColors.buttonColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: "half_year",
                                        child: CommonText(
                                          text: "Half year",
                                          color:
                                              context.customColors.buttonColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: "full_year",
                                        child: CommonText(
                                          text: "Full year",
                                          color:
                                              context.customColors.buttonColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        vm.changePeriod(value);
                                      }
                                    },
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: context.customColors.buttonColor,
                                    ),
                                  ),
                                ),
                              ),
                              Text("07 jule - 14 jule"),
                            ]),
                              SizedBox(
                                height: 25,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_downward,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CommonText(
                                            text: "Income",
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          CommonText(
                                            text: '${vm.totalIncome}',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: context.customColors.redColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.arrow_upward,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CommonText(
                                            text: "Speding",
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          CommonText(
                                            text: '${vm.totalExpense}',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        CustomerButton(
                          label: "All",
                          onPressed: () {
                            vm.changeTab('all');
                          },
                          backgourndColor: Color(0xff243972),
                          textColor: Colors.white,
                          isActive: vm.tabType == 'all' ? true : false,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        CustomerButton(
                          label: "Income",
                          onPressed: () {
                            vm.changeTab('income');
                          },
                          backgourndColor: Colors.grey[200],
                          textColor: Color(0xff243972),
                          isActive: vm.tabType == 'income' ? true : false,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        CustomerButton(
                          label: "Spending",
                          onPressed: () {
                            vm.changeTab('expense');
                          },
                          backgourndColor: Colors.grey[200],
                          textColor: Color(0xff243972),
                          isActive: vm.tabType == 'expense' ? true : false,
                        ),
                      ],
                    ),
                    Container(
                      height: 600,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: vm.expenses.length,
                        itemBuilder: (context, index) {
                          final expense = vm.expenses[index];
                          return ListTile(
                            leading: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                        255, 235, 232, 232),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    expense.category == "Income"
                                        ? Icons.arrow_downward_outlined
                                        : Icons.arrow_upward_outlined,
                                    color: expense.category == "Income"
                                        ? Colors.green
                                        : context.customColors.redColor,
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              "${expense.title}",
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              '${expense.category}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${expense.amount}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: expense.category == 'Income'
                                        ? Colors.green
                                        : context.customColors.redColor,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                Text(
                                  "${expense.date.day}/${expense.date.month}/${expense.date.year}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  showAddwalletDialog(viewModel) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Add Transaction"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: viewModel.amountController,
                decoration: InputDecoration(
                  labelText: "Amount",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: viewModel.descriptionController,
                decoration: InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Type",
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: "Income",
                    child: Text("Income"),
                  ),
                  DropdownMenuItem(
                    value: "Expense",
                    child: Text("Expense"),
                  ),
                ],
                onChanged: (value) {
                  viewModel.categoryController.text = value!;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (viewModel.validateAndSubmit()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Transaction added successfully!"),
                    ),
                  );
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Please fill all fields!"),
                    ),
                  );
                }
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
