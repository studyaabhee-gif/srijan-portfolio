import 'json_utils.dart';

class LinkItem {
  const LinkItem({required this.kind, required this.label, required this.url, this.handle});
  final String kind, label, url;
  final String? handle;
  factory LinkItem.fromJson(Json j) =>
      LinkItem(kind: str(j['kind']), label: str(j['label']), url: str(j['url']), handle: optStr(j['handle']));
}

class Kpi {
  const Kpi(this.value, this.label);
  final String value, label;
  factory Kpi.fromJson(Json j) => Kpi(str(j['value']), str(j['label']));
}

class Appointment {
  const Appointment({required this.role, required this.organization, required this.period, required this.current});
  final String role, organization, period;
  final bool current;
  factory Appointment.fromJson(Json j) => Appointment(
        role: str(j['role']),
        organization: str(j['organization']),
        period: str(j['period']),
        current: j['current'] == true,
      );
}

class Education {
  const Education({required this.degree, required this.field, required this.institution});
  final String degree, field, institution;
  factory Education.fromJson(Json j) =>
      Education(degree: str(j['degree']), field: str(j['field']), institution: str(j['institution']));
}

class EditorialBoard {
  const EditorialBoard({required this.role, required this.journal, this.url});
  final String role, journal;
  final String? url;
  factory EditorialBoard.fromJson(Json j) =>
      EditorialBoard(role: str(j['role']), journal: str(j['journal']), url: optStr(j['url']));
}

class Honor {
  const Honor({
    required this.title,
    required this.date,
    required this.conferredBy,
    required this.citation,
    this.year,
    this.image,
  });
  final String title, date, conferredBy, citation;
  final int? year;
  final String? image;
  factory Honor.fromJson(Json j) => Honor(
        title: str(j['title']),
        date: str(j['date']),
        year: optInt(j['year']),
        conferredBy: str(j['conferredBy']),
        citation: str(j['citation']),
        image: optStr(j['image']),
      );
}

class TimelineEntry {
  const TimelineEntry({
    required this.period,
    required this.title,
    required this.organization,
    required this.description,
    required this.kind,
  });
  final String period, title, organization, description, kind;
  factory TimelineEntry.fromJson(Json j) => TimelineEntry(
        period: str(j['period']),
        title: str(j['title']),
        organization: str(j['organization']),
        description: str(j['description']),
        kind: str(j['kind']),
      );
}

class TeachingSubject {
  const TeachingSubject(this.subject, this.levels);
  final String subject;
  final List<String> levels;
  factory TeachingSubject.fromJson(Json j) => TeachingSubject(str(j['subject']), strings(j['levels']));
}

class ResearchPillar {
  const ResearchPillar({required this.title, required this.summary, required this.keywords});
  final String title, summary;
  final List<String> keywords;
  factory ResearchPillar.fromJson(Json j) =>
      ResearchPillar(title: str(j['title']), summary: str(j['summary']), keywords: strings(j['keywords']));
}

class Supervision {
  const Supervision({required this.intro, required this.areas, required this.steps});
  final String intro;
  final List<String> areas, steps;
  factory Supervision.fromJson(Json j) =>
      Supervision(intro: str(j['intro']), areas: strings(j['areas']), steps: strings(j['steps']));
}

class Collaborator {
  const Collaborator({required this.name, required this.short, required this.kind, required this.country, this.hub = false});
  final String name, short, kind, country;
  final bool hub;
  factory Collaborator.fromJson(Json j) => Collaborator(
        name: str(j['name']),
        short: str(j['short']),
        kind: str(j['kind']),
        country: str(j['country']),
        hub: j['hub'] == true,
      );
}

class Profile {
  const Profile({
    required this.name,
    required this.shortName,
    required this.credentials,
    required this.crest,
    required this.title,
    required this.headline,
    required this.institution,
    required this.department,
    required this.faculty,
    required this.address,
    required this.location,
    required this.emails,
    required this.phone,
    required this.portrait,
    required this.bio,
    required this.badges,
    required this.links,
    required this.kpis,
    required this.appointments,
    required this.education,
    required this.editorialBoards,
    required this.honors,
    required this.timeline,
    required this.teaching,
    required this.researchPillars,
    required this.supervision,
    required this.collaborators,
    this.mobile,
    this.officeAddress,
  });

  final String name, shortName, credentials, crest, title, headline;
  final String institution, department, faculty, address, location, phone, portrait;

  /// Personal mobile and office address (optional in the seed).
  final String? mobile, officeAddress;
  final List<String> emails, bio, badges;
  final List<LinkItem> links;
  final List<Kpi> kpis;
  final List<Appointment> appointments;
  final List<Education> education;
  final List<EditorialBoard> editorialBoards;
  final List<Honor> honors;
  final List<TimelineEntry> timeline;
  final List<TeachingSubject> teaching;
  final List<ResearchPillar> researchPillars;
  final Supervision supervision;
  final List<Collaborator> collaborators;

  LinkItem? link(String kind) {
    for (final l in links) {
      if (l.kind == kind) return l;
    }
    return null;
  }

  factory Profile.fromJson(Json j) => Profile(
        name: str(j['name']),
        shortName: str(j['shortName']),
        credentials: str(j['credentials']),
        crest: str(j['crest']),
        title: str(j['title']),
        headline: str(j['headline']),
        institution: str(j['institution']),
        department: str(j['department']),
        faculty: str(j['faculty']),
        address: str(j['address']),
        location: str(j['location']),
        emails: strings(j['emails']),
        phone: str(j['phone']),
        mobile: optStr(j['mobile']),
        officeAddress: optStr(j['officeAddress']),
        portrait: str(j['portrait'], 'assets/images/profile/hero_portrait.jpg'),
        bio: strings(j['bio']),
        badges: strings(j['badges']),
        links: objects(j['links'], LinkItem.fromJson),
        kpis: objects(j['kpis'], Kpi.fromJson),
        appointments: objects(j['appointments'], Appointment.fromJson),
        education: objects(j['education'], Education.fromJson),
        editorialBoards: objects(j['editorialBoards'], EditorialBoard.fromJson),
        honors: objects(j['honors'], Honor.fromJson),
        timeline: objects(j['timeline'], TimelineEntry.fromJson),
        teaching: objects(j['teaching'], TeachingSubject.fromJson),
        researchPillars: objects(j['researchPillars'], ResearchPillar.fromJson),
        supervision: Supervision.fromJson(Map<String, dynamic>.from((j['supervision'] as Map?) ?? const {})),
        collaborators: objects(j['collaborators'], Collaborator.fromJson),
      );
}
