enum MbbsYear {
  first('1st Year', '1st'),
  second('2nd Year', '2nd'),
  third('3rd Year', '3rd'),
  fourth('4th Year', '4th'),
  finalYear('5th Year / Final Year', 'Final');

  const MbbsYear(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}
