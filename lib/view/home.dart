import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
      leading: Icon(Icons.person_pin),
      title: Center(child:Text("All wallets")),
      actions: [
        IconButton(onPressed: (){}, icon: Icon(Icons.calendar_month))
      ],
     ),
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
                    Text("Total balance"),
                    Text("\$ 12364"),
                  ],
                ),
              ),
            )

            ,Container(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween ,
                    children: [
                      Text("This week"),
                      Text("07 jule - 14 jule")
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween ,
                    children: [
                      Row(
                        children: [
                          Container(
                            child: Icon(Icons.arrow_downward),
                          ),
                          Column(
                            children: [
                              Text("income"),
                              Text('\$ 4236')
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            child: Icon(Icons.arrow_upward),
                          ),
                          Column(
                            children: [
                              Text("spending"),
                              Text('\$ 4236')
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            )
          
            ,Container(
              child:Column(
                children: [
                  Container(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text('All'),
                        Text('Income'),
                        Text('Spending'),
                        
                      ],
                    ),
                  ),
                  Container(
                    height: 200,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemBuilder: (context,index){
                      return ListTile(
                        leading: Icon(Icons.phone),
                        title: Text("Bitcoin"),
                        subtitle: Text('Exachange Treding'),
                        trailing: Text('+13232'),
                      ); 
                    }),
                  )

                ],
              ) ,
            )
          ],
        ),
       ),
     ),
    );
  }
}
