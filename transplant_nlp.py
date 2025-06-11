import spacy
import medspacy

from medspacy.target_matcher import TargetRule

def initialize_transplant_pipeline():
    nlp = spacy.blank("en") # create blank english spacy pipeline
    nlp.tokenizer = create_medspacy_tokenizer(nlp) # add medspacy tokenization w/ more aggressive tokenization than spacy has by default

    # sentencizer with additional punctuation character for newlines
    sents = nlp.add_pipe("sentencizer", config={"punct_chars": ["\n"]})

    # concept tagger creates basic tags for common vocabulary items like anatomical sites and transplant keywords
    tagger = nlp.add_pipe("medspacy_concept_tagger") 
    tagger.add(TargetRule.from_json("concept_tagger_rules.json"))

    # add the rest of the rules that build on concept tagger terms
    ruler = nlp.add_pipe("entity_ruler", config={"phrase_matcher_attr":"LOWER"})
    ruler.from_disk("transplant_patterns.jsonl")

    # add ConText algorithm rules with additional modifications for transplant-related concepts
    context = nlp.add_pipe("medspacy_context", config={"rules":"transplant_context_rules.json", "max_targets": 2, "max_scope":8, "excluded_types": ["EXCLUDE", "DATE", "RELATIVE_DATE"]})
    context.context_attributes_mapping["DATE_EVENT"] = {"is_historical": True}

    # add basic sectionizer
    sectionizer = nlp.add_pipe("medspacy_sectionizer")

    return nlp