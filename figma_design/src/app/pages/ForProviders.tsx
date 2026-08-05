import { DollarSign, Users, Calendar, TrendingUp, CheckCircle2, Shield, Smartphone, Award } from 'lucide-react';
import { Link } from 'react-router';

export default function ForProvidersPage() {
  const benefits = [
    {
      icon: Users,
      title: 'Reach More Customers',
      description: 'Connect with thousands of potential customers actively looking for services in your area.'
    },
    {
      icon: DollarSign,
      title: 'Grow Your Income',
      description: 'Set your own rates and increase your earnings by taking on more jobs that fit your schedule.'
    },
    {
      icon: Calendar,
      title: 'Flexible Schedule',
      description: 'Work on your own terms. Choose which jobs to accept and when you want to work.'
    },
    {
      icon: Shield,
      title: 'Secure Payments',
      description: 'Get paid securely and on time through our trusted payment platform. No more chasing payments.'
    },
    {
      icon: Award,
      title: 'Build Your Reputation',
      description: 'Earn reviews and build a stellar reputation that helps you win more jobs in the future.'
    },
    {
      icon: Smartphone,
      title: 'Easy to Use',
      description: 'Manage your business on the go with our mobile-friendly platform. Accept jobs, chat with clients, and more.'
    }
  ];

  const steps = [
    {
      number: '1',
      title: 'Create Your Profile',
      description: 'Sign up and create a professional profile showcasing your skills, experience, and services.'
    },
    {
      number: '2',
      title: 'Get Verified',
      description: 'Complete our simple verification process to build trust with potential customers.'
    },
    {
      number: '3',
      title: 'Browse Requests',
      description: 'View service requests in your area and send proposals for jobs that interest you.'
    },
    {
      number: '4',
      title: 'Get Hired & Paid',
      description: 'Once hired, complete the job and receive secure payment directly to your account.'
    }
  ];

  const stats = [
    { number: '20,000+', label: 'Active Providers' },
    { number: '4.8★', label: 'Average Rating' },
    { number: '50,000+', label: 'Jobs Completed' },
    { number: '$2M+', label: 'Earned by Providers' }
  ];

  const testimonials = [
    {
      name: 'John Martinez',
      service: 'Home Repair Specialist',
      quote: 'NeighborHelp has transformed my business. I\'ve doubled my income and built a steady client base in just 6 months.',
      rating: 5
    },
    {
      name: 'Sarah Chen',
      service: 'House Cleaning Professional',
      quote: 'The platform is so easy to use, and I love having the flexibility to choose my own schedule. Highly recommend!',
      rating: 5
    },
    {
      name: 'Michael Thompson',
      service: 'Personal Trainer',
      quote: 'Great way to find new clients! The secure payment system gives me peace of mind, and customers are always responsive.',
      rating: 5
    }
  ];

  return (
    <>
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-[#e8eef5] to-white py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-3xl mx-auto">
            <h1 className="text-5xl font-bold text-gray-900 mb-4">Grow Your Business with NeighborHelp</h1>
            <p className="text-xl text-gray-600 mb-8">
              Join thousands of service providers earning more by connecting with customers in their community.
            </p>
            <Link to="/signup">
              <button className="px-8 py-4 bg-[#1e3a5f] text-white rounded-lg hover:bg-[#152d47] cursor-pointer transition-colors text-lg font-semibold">
                Become a Provider
              </button>
            </Link>
          </div>
        </div>
      </section>

      {/* Stats Section */}
      <section className="py-12 bg-[#1e3a5f]">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
            {stats.map((stat, index) => (
              <div key={index} className="text-center">
                <div className="text-4xl font-bold text-white mb-2">{stat.number}</div>
                <div className="text-gray-300">{stat.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Benefits Section */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Why Providers Love NeighborHelp</h2>
            <p className="text-gray-600">Everything you need to succeed</p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {benefits.map((benefit, index) => (
              <div key={index} className="bg-gray-50 rounded-xl p-6 hover:shadow-md transition-shadow">
                <div className="w-12 h-12 bg-[#1e3a5f] rounded-lg flex items-center justify-center mb-4">
                  <benefit.icon className="w-6 h-6 text-white" />
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">{benefit.title}</h3>
                <p className="text-gray-600">{benefit.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works Section */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">How to Get Started</h2>
            <p className="text-gray-600">Start earning in 4 simple steps</p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
            {steps.map((step, index) => (
              <div key={index} className="relative">
                <div className="bg-white rounded-xl p-6 h-full">
                  <div className="w-12 h-12 bg-[#4a7c2c] rounded-full flex items-center justify-center mb-4 text-white text-xl font-bold">
                    {step.number}
                  </div>
                  <h3 className="text-lg font-bold text-gray-900 mb-2">{step.title}</h3>
                  <p className="text-gray-600 text-sm">{step.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Testimonials Section */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Success Stories</h2>
            <p className="text-gray-600">Hear from providers who are thriving on NeighborHelp</p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {testimonials.map((testimonial, index) => (
              <div key={index} className="bg-gray-50 rounded-xl p-6">
                <div className="flex items-center gap-1 mb-4">
                  {[...Array(testimonial.rating)].map((_, i) => (
                    <div key={i} className="text-yellow-500">★</div>
                  ))}
                </div>
                <p className="text-gray-700 mb-4 italic">"{testimonial.quote}"</p>
                <div>
                  <div className="font-bold text-gray-900">{testimonial.name}</div>
                  <div className="text-sm text-gray-600">{testimonial.service}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 bg-gradient-to-br from-[#1e3a5f] to-[#152d47]">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">Ready to Grow Your Business?</h2>
          <p className="text-lg text-gray-200 mb-8">
            Join NeighborHelp today and start connecting with customers who need your services.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link to="/signup">
              <button className="px-8 py-4 bg-[#4a7c2c] text-white rounded-lg hover:bg-[#3d6624] cursor-pointer transition-colors text-lg font-semibold">
                Sign Up Now
              </button>
            </Link>
            <button className="px-8 py-4 bg-white text-[#1e3a5f] rounded-lg hover:bg-gray-100 cursor-pointer transition-colors text-lg font-semibold">
              Learn More
            </button>
          </div>
        </div>
      </section>
    </>
  );
}
