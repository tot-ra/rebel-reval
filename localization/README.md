# Offline dialogue localization

Runtime dialogue localization is authored and bundled. Each locale file contains a
`locale` tag and a flat `translations` object. `DialogueLocalization` resolves the
requested locale, its language base, the configured default locale, and finally the
inline source text. Missing translations never trigger network access or a runtime
LLM request.
