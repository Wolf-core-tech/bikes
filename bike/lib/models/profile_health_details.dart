enum ProfileFieldVisibility {
  everyone('everyone', 'Everyone'),
  friendsOnly('friends', 'Friends only'),
  noOne('none', 'No one');

  const ProfileFieldVisibility(this.value, this.label);

  final String value;
  final String label;

  static ProfileFieldVisibility fromValue(Object? value) =>
      ProfileFieldVisibility.values.firstWhere(
        (visibility) => visibility.value == value,
        orElse: () => ProfileFieldVisibility.noOne,
      );
}

class ProfileHealthDetails {
  const ProfileHealthDetails({
    this.dateOfBirth,
    this.bloodGroup,
    this.healthIssue,
    this.dateOfBirthVisibility = ProfileFieldVisibility.noOne,
    this.healthIssueVisibility = ProfileFieldVisibility.noOne,
  });

  final String? dateOfBirth;
  final String? bloodGroup;
  final String? healthIssue;
  final ProfileFieldVisibility dateOfBirthVisibility;
  final ProfileFieldVisibility healthIssueVisibility;

  ProfileHealthDetails copyWith({
    String? dateOfBirth,
    String? bloodGroup,
    String? healthIssue,
    ProfileFieldVisibility? dateOfBirthVisibility,
    ProfileFieldVisibility? healthIssueVisibility,
    bool clearDateOfBirth = false,
    bool clearBloodGroup = false,
    bool clearHealthIssue = false,
  }) => ProfileHealthDetails(
    dateOfBirth: clearDateOfBirth ? null : dateOfBirth ?? this.dateOfBirth,
    bloodGroup: clearBloodGroup ? null : bloodGroup ?? this.bloodGroup,
    healthIssue: clearHealthIssue ? null : healthIssue ?? this.healthIssue,
    dateOfBirthVisibility:
        dateOfBirthVisibility ?? this.dateOfBirthVisibility,
    healthIssueVisibility:
        healthIssueVisibility ?? this.healthIssueVisibility,
  );
}
