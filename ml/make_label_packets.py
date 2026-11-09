"""Create explicitly hypothetical, unlabeled cases for independent human review."""
from __future__ import annotations

import argparse
import csv
import math
import random
from pathlib import Path


def write_csv(path, rows):
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("ml/labeling"))
    args = parser.parse_args(argv)
    args.output.mkdir(parents=True, exist_ok=True)
    if (args.output / "provider_matches.csv").exists():
        raise ValueError("A labeling packet already exists. Use another output folder to preserve human work.")
    rng = random.Random(20261109)
    services = [("House Cleaning", "Domestic Work NC II"), ("Basic Carpentry", "Carpentry NC II"), ("Computer Repair", "Computer Systems Servicing NC II"), ("Aircon Cleaning", "RAC Servicing (DomRAC) NC II")]
    rows = []
    for index in range(45):
        service, qualification = services[index % len(services)]
        candidates = []
        for candidate in range(5):
            accepted = rng.choice([0, 1, 2, 5, 12, 30, 80])
            completed = int(accepted * rng.choice([.5, .7, .85, 1.]))
            reviews = rng.choice([0, 2, 5, 15, 40])
            candidates.append({"query_id": f"request-{index+1:03}", "provider_id": f"candidate-{candidate+1}", "group_id": f"request-{index+1:03}",
                "scenario": f"Hypothetical Panabo request: {service}; customer needs a provider for an agreed half-day visit. Compare suitability for that period, not a guarantee of a contract.",
                "required_qualification": qualification, "distance_km": round(rng.uniform(.3, 17), 2), "max_search_radius_km": 15,
                "service_radius_km": rng.choice([5, 10, 15]), "identity_verified": "true", "certificate_verified": "true" if candidate < 4 else rng.choice(["true", "false"]),
                "account_active": "true", "service_matches": "true", "available": "true" if candidate < 2 else rng.choice(["true", "false"]),
                "bayesian_rating": round((10 * 3.5 + reviews * rng.uniform(3, 5)) / (10 + reviews), 3), "review_count": reviews,
                "completed_bookings": completed, "accepted_bookings": accepted, "relevance": "", "label_source": "", "reviewer_1_grade": "", "reviewer_2_grade": "", "adjudication_notes": "",
                "data_origin": "hypothetical_case_for_human_labeling"})
        # At least two covered, qualified, available options so relative judgments
        # are useful, instead of a packet containing only exclusion questions.
        for candidate in candidates[:2]:
            candidate["distance_km"] = round(rng.uniform(.3, 4.5), 2)
        rng.shuffle(candidates)
        rows.extend(candidates)
    write_csv(args.output / "provider_matches.csv", rows)
    # These are draft authored scenarios, not customer records or gold labels.
    # Native speakers must correct text and assign labels before any training.
    drafts = [
        "Maayo kaayo ang trabaho ug nahuman sa gikasabotang oras.",
        "Wala niabot ang trabahante bisan naghulat ko tibuok buntag.",
        "Miabot ang provider alas nuwebe sa buntag.",
        "Limpyo ug hapsay ang balay pagkahuman sa serbisyo.",
        "Dili ko kontento kay wala naayo ang among aircon.",
        "Duha ka tawo ang mianhi aron motabang sa paglimpyo.",
        "Buotan ug matinahuron ang provider, salamat kaayo.",
        "Daghan pa gihapong hugaw bisan giingon niyang nahuman na.",
        "Gipakita niya ang listahan sa mga materyales nga gamiton.",
        "Dili bati ang iyang trabaho, ganahan ko sa resulta.",
        "Dili maayo ang pag-ayo, mibalik dayon ang problema.",
        "Ang serbisyo gihimo niadtong Sabado sa hapon.",
        "Sulit ang bayad kay maayo ug lig-on ang pagkahimo.",
        "Nangayo siya og dugang bayad nga wala namo gisabot.",
        "Nagkasabot mi sa presyo sa wala pa magsugod.",
        "Maayo unta ang resulta apan nalangan og duha ka adlaw.",
        "Maayo kaayo kuno, pero wala gani nahuman ang trabaho.",
        "Adunay litrato sa trabaho sa wala pa ug human niini.",
        "Paspas ang serbisyo ug klaro ang iyang pagpasabot.",
        "Nabalaka ko kay wala niya gisunod ang safety instructions.",
        "Gihatag nako ang address ug oras sa among sabot.",
        "Walay problema sa trabaho; limpyo ug sakto ang tanan.",
        "Wala ko ganahi sa iyang bastos nga pagpakigsulti.",
        "Nagpadala siya og mensahe sa pag-abot niya.",
        "Satisfied ko sa repair, tarong kaayo ang pagkahimo.",
        "Okay unta pero wala niya limpyohi ang gitrabahoan.",
        "Ang provider nagdala sa kaugalingong mga gamit.",
        "Naa pa gihapoy problema ug wala siya mitubag sa akong mensahe.",
        "Mas maayo pa ang resulta kaysa akong gilaoman.",
        "Gisulat namo sa kontrata ang mga buluhaton ug bayad.",
    ]
    write_csv(args.output / "cebuano_review_drafts.csv", [{"example_id":f"ceb-draft-{i+1:03}","language":"Cebuano/Bisaya","text":text,"corrected_text":"","reviewer_1_label":"","reviewer_2_label":"","final_label":"","native_speaker_verified":"","notes":"","data_origin":"AI-authored draft; not public customer data; not a gold benchmark"} for i,text in enumerate(drafts)])
    write_csv(args.output / "real_review_collection.csv", [{"text":"","label":"","language":"","group_id":"","split":"","source":"","reviewer_1_label":"","reviewer_2_label":"","adjudication_notes":"","permission_or_license":""}])
    print(f"Created {len(rows)} provider candidates across 45 hypothetical requests; 30 Cebuano drafts require native-speaker review.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
