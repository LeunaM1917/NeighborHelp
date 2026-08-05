enum MarketingRoute {
  home,
  browseServices,
  howItWorks,
  forProviders,
  aboutUs,
}

extension MarketingRoutePath on MarketingRoute {
  String get label {
    switch (this) {
      case MarketingRoute.home:
        return 'Home';
      case MarketingRoute.browseServices:
        return 'Browse Services';
      case MarketingRoute.howItWorks:
        return 'How It Works';
      case MarketingRoute.forProviders:
        return 'For Providers';
      case MarketingRoute.aboutUs:
        return 'About Us';
    }
  }
}
