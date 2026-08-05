import { Search, Home, Sparkles, DogIcon, Wrench, Car, GraduationCap, Utensils, TrendingUp, Star, ThumbsUp, Filter } from 'lucide-react';
import { ImageWithFallback } from '../components/figma/ImageWithFallback';

export default function BrowseServicesPage() {
  const categories = [
    { icon: Home, name: 'Home Repair', color: 'bg-[#e8eef5] text-[#1e3a5f]', count: 234 },
    { icon: Sparkles, name: 'Cleaning', color: 'bg-[#e8f4e0] text-[#4a7c2c]', count: 189 },
    { icon: DogIcon, name: 'Pet Care', color: 'bg-orange-50 text-orange-600', count: 156 },
    { icon: Wrench, name: 'Handyman', color: 'bg-purple-50 text-purple-600', count: 298 },
    { icon: Car, name: 'Moving', color: 'bg-red-50 text-red-600', count: 87 },
    { icon: GraduationCap, name: 'Tutoring', color: 'bg-indigo-50 text-indigo-600', count: 167 },
    { icon: Utensils, name: 'Catering', color: 'bg-yellow-50 text-yellow-600', count: 93 },
    { icon: TrendingUp, name: 'Consulting', color: 'bg-gray-50 text-gray-600', count: 142 }
  ];

  const allServices = [
    {
      title: 'House Cleaning',
      image: 'https://images.unsplash.com/photo-1581578949510-fa7315c4c350?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxob3VzZSUyMGNsZWFuaW5nJTIwc2VydmljZXxlbnwxfHx8fDE3Nzg0NzUyNzR8MA&ixlib=rb-4.1.0&q=80&w=1080',
      category: 'Cleaning',
      rating: 4.9,
      reviews: 127,
      startingPrice: 60
    },
    {
      title: 'Tutoring',
      image: 'https://images.unsplash.com/photo-1758685733907-42e9651721f5?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx0dXRvcmluZyUyMHRlYWNoZXIlMjBzdHVkZW50fGVufDF8fHx8MTc3ODQ5MjI2NXww&ixlib=rb-4.1.0&q=80&w=1080',
      category: 'Education',
      rating: 4.8,
      reviews: 95,
      startingPrice: 45
    },
    {
      title: 'Home Repair',
      image: 'https://images.unsplash.com/photo-1562259929-b4e1fd3aef09?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxob21lJTIwcmVwYWlyJTIwaGFuZHltYW58ZW58MXx8fHwxNzc4NDkyMjY2fDA&ixlib=rb-4.1.0&q=80&w=1080',
      category: 'Home Repair',
      rating: 5.0,
      reviews: 203,
      startingPrice: 80
    },
    {
      title: 'Pet Sitting',
      image: 'https://images.unsplash.com/photo-1774979131520-37061ac9d68c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxwZXQlMjBzaXR0aW5nJTIwZG9nJTIwY2FyZXxlbnwxfHx8fDE3Nzg0OTIyNjZ8MA&ixlib=rb-4.1.0&q=80&w=1080',
      category: 'Pet Care',
      rating: 4.9,
      reviews: 156,
      startingPrice: 35
    },
    {
      title: 'Lawn Care',
      image: 'https://images.unsplash.com/photo-1748567353428-323d3c8f73a8?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxsYXduJTIwY2FyZSUyMGdhcmRlbmluZ3xlbnwxfHx8fDE3Nzg0OTIyNjd8MA&ixlib=rb-4.1.0&q=80&w=1080',
      category: 'Lawn & Garden',
      rating: 4.7,
      reviews: 89,
      startingPrice: 50
    },
    {
      title: 'Personal Training',
      image: 'https://images.unsplash.com/photo-1536922246289-88c42f957773?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxwZXJzb25hbCUyMHRyYWluaW5nJTIwZml0bmVzc3xlbnwxfHx8fDE3Nzg0OTIyNjd8MA&ixlib=rb-4.1.0&q=80&w=1080',
      category: 'Fitness',
      rating: 5.0,
      reviews: 142,
      startingPrice: 70
    },
    {
      title: 'Plumbing Services',
      image: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400&q=80',
      category: 'Home Repair',
      rating: 4.8,
      reviews: 178,
      startingPrice: 90
    },
    {
      title: 'Electrical Work',
      image: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?w=400&q=80',
      category: 'Home Repair',
      rating: 4.9,
      reviews: 165,
      startingPrice: 85
    },
    {
      title: 'Interior Painting',
      image: 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?w=400&q=80',
      category: 'Home Improvement',
      rating: 4.7,
      reviews: 134,
      startingPrice: 55
    }
  ];

  return (
    <>
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-[#e8eef5] to-white py-12">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">Browse Services</h1>
          <p className="text-lg text-gray-600 mb-8">
            Explore all available services in your area
          </p>

          <div className="bg-white rounded-xl shadow-lg p-4 max-w-3xl">
            <div className="flex items-center gap-2">
              <div className="flex-1 flex items-center gap-2 px-4 py-3 bg-gray-50 rounded-lg">
                <Search className="w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="Search for services..."
                  className="flex-1 bg-transparent outline-none text-gray-900 placeholder-gray-500"
                />
              </div>
              <button className="px-6 py-3 bg-[#1e3a5f] text-white rounded-lg hover:bg-[#152d47] flex items-center gap-2 cursor-pointer transition-colors">
                <Search className="w-5 h-5" />
                Search
              </button>
            </div>
          </div>
        </div>
      </section>

      {/* Categories */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between mb-8">
            <h2 className="text-2xl font-bold text-gray-900">Service Categories</h2>
            <button className="flex items-center gap-2 px-4 py-2 border-2 border-gray-200 rounded-lg hover:border-[#1e3a5f] cursor-pointer transition-colors">
              <Filter className="w-4 h-4" />
              <span>Filter</span>
            </button>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-16">
            {categories.map((category, index) => (
              <button
                key={index}
                className="p-6 bg-white border-2 border-gray-100 rounded-xl hover:border-[#1e3a5f] hover:shadow-lg transition-all group cursor-pointer"
              >
                <div className={`w-12 h-12 ${category.color} rounded-lg flex items-center justify-center mb-3 group-hover:scale-110 transition-transform`}>
                  <category.icon className="w-6 h-6" />
                </div>
                <h3 className="font-semibold text-gray-900 mb-1">{category.name}</h3>
                <p className="text-sm text-gray-500">{category.count} services</p>
              </button>
            ))}
          </div>

          <h2 className="text-2xl font-bold text-gray-900 mb-8">All Services</h2>
          <div className="grid md:grid-cols-3 gap-6">
            {allServices.map((service, index) => (
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
                  <div className="absolute top-3 left-3 bg-[#1e3a5f] text-white text-xs px-3 py-1 rounded-full">
                    {service.category}
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
