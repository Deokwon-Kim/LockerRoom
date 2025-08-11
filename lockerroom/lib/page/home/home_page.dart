import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lockerroom/const/color.dart';
import 'package:lockerroom/model/team_model.dart';
import 'package:lockerroom/page/schedule/schedule.dart';
import 'package:lockerroom/provider/team_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  final TeamModel teamModel;
  const HomePage({super.key, required this.teamModel});

  @override
  Widget build(BuildContext context) {
    return Consumer<TeamProvider>(
      builder: (context, teamProvider, child) {
        final selectedTeam = teamProvider.selectedTeam ?? teamModel;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: selectedTeam.color,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset(selectedTeam.symbolPath),
            ),
            title: Text(
              selectedTeam.name,
              style: TextStyle(color: WHITE, fontSize: 17),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SchedulePage(teamModel: teamModel),
                    ),
                  );
                },
                icon: Icon(CupertinoIcons.bell, color: WHITE),
              ),
            ],
          ),
          body: Center(),
        );
      },
    );
  }
}
