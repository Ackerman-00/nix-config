# Shared helpers for the HyperFrames module: feed parsing.
{
  npmLatest = feed: (builtins.fromJSON (builtins.readFile feed)).latest;

  pypiLatest = feed: (builtins.fromJSON (builtins.readFile feed)).info.version;
}
