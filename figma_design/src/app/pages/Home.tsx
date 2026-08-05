import { Search, Home, Sparkles, DogIcon, Wrench, Car, GraduationCap, Utensils, TrendingUp, CheckCircle2, MessageSquare, ThumbsUp, Star } from 'lucide-react';
import { ImageWithFallback } from '../components/figma/ImageWithFallback';
import { useState } from 'react';

export default function HomePage() {
  const [searchMode, setSearchMode] = useState<'service' | 'provider'>('service');

  const categories = [
    { icon: Home, name: 'Home Repair', color: 'bg-[#e8eef5] text-[#1e3a5f]' },
    { icon: Sparkles, name: 'Cleaning', color: 'bg-[#e8f4e0] text-[#4a7c2c]' },
    { icon: DogIcon, name: 'Pet Care', color: 'bg-orange-50 text-orange-600' },
    { icon: Wrench, name: 'Handyman', color: 'bg-purple-50 text-purple-600' },
    { icon: Car, name: 'Moving', color: 'bg-red-50 text-red-600' },
    { icon: GraduationCap, name: 'Tutoring', color: 'bg-indigo-50 text-indigo-600' },
    { icon: Utensils, name: 'Catering', color: 'bg-yellow-50 text-yellow-600' },
    { icon: TrendingUp, name: 'More', color: 'bg-gray-50 text-gray-600' }
  ];

  const steps = [
    {
      icon: Search,
      title: 'Post Request',
      description: 'Tell us what service you need and provide details'
    },
    {
      icon: MessageSquare,
      title: 'Review Proposals',
      description: 'Compare qualified providers and their offers'
    },
    {
      icon: CheckCircle2,
      title: 'Hire & Review',
      description: 'Choose the best match and leave feedback'
    }
  ];

  const services = [
    {
      title: 'House Cleaning',
      image: 'https://images.unsplash.com/photo-1581578949510-fa7315c4c350?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxob3VzZSUyMGNsZWFuaW5nJTIwc2VydmljZXxlbnwxfHx8fDE3Nzg0NzUyNzR8MA&ixlib=rb-4.1.0&q=80&w=1080',
      rating: 4.9,
      reviews: 127,
      startingPrice: 60
    },
    {
      title: 'Tutoring',
      image: 'https://images.unsplash.com/photo-1758685733907-42e9651721f5?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx0dXRvcmluZyUyMHRlYWNoZXIlMjBzdHVkZW50fGVufDF8fHx8MTc3ODQ5MjI2NXww&ixlib=rb-4.1.0&q=80&w=1080',
      rating: 4.8,
      reviews: 95,
      startingPrice: 45
    },
    {
      title: 'Home Repair',
      image: 'https://images.unsplash.com/photo-1562259929-b4e1fd3aef09?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxob21lJTIwcmVwYWlyJTIwaGFuZHltYW58ZW58MXx8fHwxNzc4NDkyMjY2fDA&ixlib=rb-4.1.0&q=80&w=1080',
      rating: 5.0,
      reviews: 203,
      startingPrice: 80
    },
    {
      title: 'Pet Sitting',
      image: 'https://images.unsplash.com/photo-1774979131520-37061ac9d68c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxwZXQlMjBzaXR0aW5nJTIwZG9nJTIwY2FyZXxlbnwxfHx8fDE3Nzg0OTIyNjZ8MA&ixlib=rb-4.1.0&q=80&w=1080',
      rating: 4.9,
      reviews: 156,
      startingPrice: 35
    },
    {
      title: 'Lawn Care',
      image: 'https://images.unsplash.com/photo-1748567353428-323d3c8f73a8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxsYXduJTIwY2FyZSUyMGdhcmRlbmluZ3xlbnwxfHx8fDE3Nzg0OTIyNjd8MA&ixlib=rb-4.1.0&q=80&w=1080',
      rating: 4.7,
      reviews: 89,
      startingPrice: 50
    },
    {
      title: 'Personal Training',
      image: 'https://images.unsplash.com/photo-1536922246289-88c42f957773?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxwZXJzb25hbCUyMHRyYWluaW5nJTIwZml0bmVzc3xlbnwxfHx8fDE3Nzg0OTIyNjd8MA&ixlib=rb-4.1.0&q=80&w=1080',
      rating: 5.0,
      reviews: 142,
      startingPrice: 70
    }
  ];

  return (
    <>
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-[#e8eef5] to-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h1 className="text-5xl font-bold text-gray-900 leading-tight mb-4">
                Find trusted local services in your community
              </h1>
              <p className="text-lg text-gray-600 mb-8">
                Post your request, compare and book reliable service providers near you.
                All providers are vetted and reviewed by your neighbors.
              </p>

              <div className="bg-white rounded-xl shadow-lg p-2">
                <div className="flex items-center gap-2 mb-2">
                  <button
                    onClick={() => setSearchMode('service')}
                    className={`px-4 py-2 rounded-lg text-sm transition-colors cursor-pointer ${
                      searchMode === 'service'
                        ? 'bg-[#1e3a5f] text-white'
                        : 'text-gray-600 hover:bg-gray-50'
                    }`}
                  >
                    Service Needed
                  </button>
                  <button
                    onClick={() => setSearchMode('provider')}
                    className={`px-4 py-2 rounded-lg text-sm transition-colors cursor-pointer ${
                      searchMode === 'provider'
                        ? 'bg-[#1e3a5f] text-white'
                        : 'text-gray-600 hover:bg-gray-50'
                    }`}
                  >
                    Service Providers
                  </button>
                </div>
                <div className="flex items-center gap-2">
                  <div className="flex-1 flex items-center gap-2 px-4 py-3 bg-gray-50 rounded-lg">
                    <Search className="w-5 h-5 text-gray-400" />
                    <input
                      type="text"
                      placeholder={searchMode === 'service' ? 'What service do you need?' : 'Search for service providers...'}
                      className="flex-1 bg-transparent outline-none text-gray-900 placeholder-gray-500"
                    />
                  </div>
                  <button className="px-6 py-3 bg-[#1e3a5f] text-white rounded-lg hover:bg-[#152d47] flex items-center gap-2 cursor-pointer transition-colors">
                    <Search className="w-5 h-5" />
                    Search
                  </button>
                </div>
              </div>

              <div className="flex items-center gap-6 mt-8">
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="w-5 h-5 text-[#4a7c2c]" />
                  <span className="text-sm text-gray-700">Trusted Providers</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="w-5 h-5 text-[#4a7c2c]" />
                  <span className="text-sm text-gray-700">Secure Payment</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 className="w-5 h-5 text-[#4a7c2c]" />
                  <span className="text-sm text-gray-700">Verified Services</span>
                </div>
              </div>
            </div>

            <div className="relative">
              <div className="bg-white rounded-2xl shadow-xl p-1 overflow-hidden">
                <ImageWithFallback
                  src="https://images.unsplash.com/photo-1521791136064-7986c2920216?w=800&q=80"
                  alt="Service providers"
                  className="w-full h-96 object-cover rounded-xl"
                />
              </div>

              <div className="absolute -bottom-4 -right-4 bg-white rounded-xl shadow-lg p-4 flex items-center gap-3">
                <div className="flex -space-x-2">
                  {[1, 2, 3, 4].map((i) => (
                    <div key={i} className="w-8 h-8 rounded-full bg-gradient-to-br from-[#6b9bd1] to-purple-500 border-2 border-white" />
                  ))}
                </div>
                <div>
                  <div className="text-lg font-bold text-gray-900">4.9★</div>
                  <div className="text-xs text-gray-600">20k+ Providers</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Browse by Category */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Browse by Category</h2>
            <p className="text-gray-600">Find the perfect service provider for your needs</p>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {categories.map((category, index) => (
              <button
                key={index}
                className="p-6 bg-white border-2 border-gray-100 rounded-xl hover:border-[#1e3a5f] hover:shadow-lg transition-all group cursor-pointer"
              >
                <div className={`w-12 h-12 ${category.color} rounded-lg flex items-center justify-center mb-3 group-hover:scale-110 transition-transform`}>
                  <category.icon className="w-6 h-6" />
                </div>
                <h3 className="font-semibold text-gray-900">{category.name}</h3>
              </button>
            ))}
          </div>
        </div>
      </section>

      {/* How NeighborHelp Works */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">How NeighborHelp Works</h2>
            <p className="text-gray-600">Get started in three simple steps</p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {steps.map((step, index) => (
              <div key={index} className="relative h-full">
                <div className="bg-white rounded-xl p-8 shadow-sm hover:shadow-md transition-shadow h-full flex flex-col">
                  <div className="w-14 h-14 bg-[#1e3a5f] rounded-full flex items-center justify-center mb-4">
                    <step.icon className="w-7 h-7 text-white" />
                  </div>
                  <h3 className="text-xl font-bold text-gray-900 mb-2">{step.title}</h3>
                  <p className="text-gray-600 flex-1">{step.description}</p>
                </div>
                {index < steps.length - 1 && (
                  <div className="hidden md:block absolute top-1/2 -right-4 transform -translate-y-1/2">
                    <div className="w-8 h-0.5 bg-[#c5d8ed]"></div>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Popular Services Near You */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between mb-12">
            <div>
              <h2 className="text-3xl font-bold text-gray-900 mb-2">Popular Services Near You</h2>
              <p className="text-gray-600">Top-rated providers in your area</p>
            </div>
          </div>

          <div className="grid md:grid-cols-3 gap-6">
            {services.map((service, index) => (
              <div key={index} className="bg-white border-2 border-gray-100 rounded-xl overflow-hidden hover:border-[#1e3a5f] hover:shadow-lg transition-all cursor-pointer">
                <div className="h-48 bg-gradient-to-br from-[#e8eef5] to-purple-100 relative">
                  <ImageWithFallback
                    src={service.image}
                    alt={service.title}
                    className="w-full h-full object-cover"
                  />
                  <div className="absolute top-3 right-3 bg-white rounded-full px-3 py-1 flex items-center gap-1">
                    <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                    <span className="text-sm font-semibold text-gray-900">{service.rating}</span>
                  </div>
                </div>
                <div className="p-5">
                  <h3 className="text-xl font-bold text-gray-900 mb-3">{service.title}</h3>
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-1 text-gray-500 text-sm">
                      <ThumbsUp className="w-4 h-4" />
                      <span>{service.reviews} reviews</span>
                    </div>
                    <div className="text-[#1e3a5f] font-semibold">
                      From ${service.startingPrice}/hr
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
