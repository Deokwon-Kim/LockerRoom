import 'package:flutter/material.dart';
import 'package:lockerroom/model/team_model.dart';
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
        return Scaffold(appBar: AppBar(backgroundColor: selectedTeam.color));
      },
    );
  }
}
