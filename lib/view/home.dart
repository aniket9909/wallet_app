import 'package:ewallet/models/expense_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ewallet/core/widgets/CUstomerButton.dart';
import 'package:ewallet/core/widgets/CustomeText.dart';
import 'package:ewallet/core/utils/color_extension.dart';

import '../viewmodels/home_view_model.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();
        Provider.of<ExpenseViewModel>(context, listen: false).listenToExpenses();
  }
  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<ExpenseViewModel>(context);
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
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.home),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.search),
              onPressed: () {},
            ),
            SizedBox(width: 40),
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {},
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
           
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Add Transaction"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Amount",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 10),
                    TextField(
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
                      onChanged: (value) {},
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
                      // Handle saving the transaction
                      Navigator.of(context).pop();
                    },
                    child: Text("Save"),
                  ),
                ],
              );
            },
          );
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
                        text: "123654",
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(60),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 10),
                                    CommonText(
                                      text: "This week",
                                      color: context.customColors.buttonColor,
                                      fontSize: 15,
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: context.customColors.buttonColor,
                                    ),
                                  ],
                                ),
                              ),
                              Text("07 jule - 14 jule"),
                            ],
                          ),
                          SizedBox(
                            height: 25,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                        text: '\$ 4236',
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
                                        text: '\$ 4236',
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
                          onPressed: () {},
                          backgourndColor: Color(0xff243972),
                          textColor: Colors.white,
                          isActive: true,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        CustomerButton(
                          label: "Income",
                          onPressed: () {},
                          backgourndColor: Colors.grey[200],
                          textColor: Color(0xff243972),
                          isActive: false,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        CustomerButton(
                          label: "Spending",
                          onPressed: () {},
                          backgourndColor: Colors.grey[200],
                          textColor: Color(0xff243972),
                          isActive: false,
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
                                      Icons.access_time,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                "${expense.title}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                'Exchange Trading',
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
                                    '+\$13232',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "12:30 PM, 12/10/2023",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
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
}
