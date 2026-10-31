class Animal {
  final int? id;
  final String tagNo;
  final String name;
  final String breed;
  final String gender; // 'Dişi' veya 'Erkek'
  final String? age; // '3 Yaşında', '8 Aylık' vb.
  final String? birthDate;
  final bool isPregnant;
  final String? inseminationDate;
  final String? estBirthDate;
  final String? notes;

  Animal({
    this.id,
    required this.tagNo,
    required this.name,
    required this.breed,
    required this.gender,
    this.age,
    this.birthDate,
    this.isPregnant = false,
    this.inseminationDate,
    this.estBirthDate,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tag_no': tagNo,
      'name': name,
      'breed': breed,
      'gender': gender,
      'age': age,
      'birth_date': birthDate,
      'is_pregnant': isPregnant ? 1 : 0,
      'insemination_date': inseminationDate,
      'est_birth_date': estBirthDate,
      'notes': notes,
    };
  }

  factory Animal.fromMap(Map<String, dynamic> map) {
    return Animal(
      id: map['id'],
      tagNo: map['tag_no'] ?? '',
      name: map['name'] ?? '',
      breed: map['breed'] ?? 'Simental',
      gender: map['gender'] ?? 'Dişi',
      age: map['age'],
      birthDate: map['birth_date'],
      isPregnant: (map['is_pregnant'] ?? 0) == 1,
      inseminationDate: map['insemination_date'],
      estBirthDate: map['est_birth_date'],
      notes: map['notes'],
    );
  }

  Animal copyWith({
    int? id,
    String? tagNo,
    String? name,
    String? breed,
    String? gender,
    String? age,
    String? birthDate,
    bool? isPregnant,
    String? inseminationDate,
    String? estBirthDate,
    String? notes,
  }) {
    return Animal(
      id: id ?? this.id,
      tagNo: tagNo ?? this.tagNo,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      birthDate: birthDate ?? this.birthDate,
      isPregnant: isPregnant ?? this.isPregnant,
      inseminationDate: inseminationDate ?? this.inseminationDate,
      estBirthDate: estBirthDate ?? this.estBirthDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Animal.fromJson(Map<String, dynamic> json) => Animal.fromMap(json);
}

class MilkRecord {
  final int? id;
  final String animalTag;
  final String date;
  final String session; // 'Sabah' veya 'Akşam'
  final double liters;
  final String? note;

  MilkRecord({
    this.id,
    required this.animalTag,
    required this.date,
    required this.session,
    required this.liters,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_tag': animalTag,
      'date': date,
      'session': session,
      'liters': liters,
      'note': note,
    };
  }

  factory MilkRecord.fromMap(Map<String, dynamic> map) {
    return MilkRecord(
      id: map['id'],
      animalTag: map['animal_tag'] ?? 'Genel Sürü',
      date: map['date'] ?? '',
      session: map['session'] ?? 'Sabah',
      liters: (map['liters'] as num).toDouble(),
      note: map['note'],
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory MilkRecord.fromJson(Map<String, dynamic> json) => MilkRecord.fromMap(json);
}

class FinanceRecord {
  final int? id;
  final String type; // 'Gelir' veya 'Gider'
  final String category;
  final double amount;
  final String date;
  final String? description;

  FinanceRecord({
    this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'category': category,
      'amount': amount,
      'date': date,
      'description': description,
    };
  }

  factory FinanceRecord.fromMap(Map<String, dynamic> map) {
    return FinanceRecord(
      id: map['id'],
      type: map['type'] ?? 'Gider',
      category: map['category'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] ?? '',
      description: map['description'],
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory FinanceRecord.fromJson(Map<String, dynamic> json) => FinanceRecord.fromMap(json);
}
