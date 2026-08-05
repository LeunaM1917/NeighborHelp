import { Heart, Users, Target, Shield, Globe, Award } from 'lucide-react';
import { Link } from 'react-router';

export default function AboutUsPage() {
  const values = [
    {
      icon: Heart,
      title: 'Community First',
      description: 'We believe in building strong, supportive communities where neighbors help neighbors thrive.'
    },
    {
      icon: Shield,
      title: 'Trust & Safety',
      description: 'We prioritize the safety and security of our users through rigorous verification and protection measures.'
    },
    {
      icon: Users,
      title: 'Inclusivity',
      description: 'Everyone deserves access to quality services. We welcome providers and customers from all backgrounds.'
    },
    {
      icon: Target,
      title: 'Excellence',
      description: 'We strive for excellence in everything we do, from our platform features to customer support.'
    }
  ];

  const milestones = [
    {
      year: '2020',
      title: 'Founded',
      description: 'NeighborHelp was born from the vision to connect communities with trusted local services.'
    },
    {
      year: '2021',
      title: 'Reached 5,000 Users',
      description: 'Our platform grew rapidly as word spread about our commitment to quality and trust.'
    },
    {
      year: '2023',
      title: 'Expanded Nationwide',
      description: 'We expanded our services to cover communities across the entire country.'
    },
    {
      year: '2026',
      title: '50,000+ Jobs Completed',
      description: 'Celebrating major milestones with a thriving community of customers and providers.'
    }
  ];

  const team = [
    {
      name: 'Jennifer Williams',
      role: 'CEO & Co-Founder',
      description: 'Former tech executive with a passion for building community-driven platforms.'
    },
    {
      name: 'David Chen',
      role: 'CTO & Co-Founder',
      description: 'Software engineer with 15+ years of experience building scalable platforms.'
    },
    {
      name: 'Maria Rodriguez',
      role: 'Head of Community',
      description: 'Community advocate dedicated to creating safe and inclusive spaces online.'
    }
  ];

  return (
    <>
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-[#e8eef5] to-white py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center max-w-3xl mx-auto">
            <h1 className="text-5xl font-bold text-gray-900 mb-4">About NeighborHelp</h1>
            <p className="text-xl text-gray-600">
              Connecting communities with trusted local service providers since 2020
            </p>
          </div>
        </div>
      </section>

      {/* Mission Section */}
      <section className="py-16 bg-white">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-3xl font-bold text-gray-900 mb-4">Our Mission</h2>
              <p className="text-lg text-gray-600 mb-4">
                At NeighborHelp, we believe that everyone deserves easy access to reliable, high-quality services in their community. Our mission is to empower local service providers and make it simple for customers to find the help they need.
              </p>
              <p className="text-lg text-gray-600">
                We're building more than just a platform – we're building trust, fostering connections, and strengthening communities one service at a time.
              </p>
            </div>
            <div className="bg-gradient-to-br from-[#1e3a5f] to-[#152d47] rounded-2xl p-12 text-white">
              <div className="flex items-center gap-4 mb-6">
                <Globe className="w-12 h-12" />
                <div>
                  <div className="text-3xl font-bold">20,000+</div>
                  <div className="text-gray-300">Service Providers</div>
                </div>
              </div>
              <div className="flex items-center gap-4 mb-6">
                <Users className="w-12 h-12" />
                <div>
                  <div className="text-3xl font-bold">100,000+</div>
                  <div className="text-gray-300">Active Customers</div>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <Award className="w-12 h-12" />
                <div>
                  <div className="text-3xl font-bold">4.8★</div>
                  <div className="text-gray-300">Average Rating</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Values Section */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Our Values</h2>
            <p className="text-gray-600">The principles that guide everything we do</p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
            {values.map((value, index) => (
              <div key={index} className="bg-white rounded-xl p-6 text-center hover:shadow-md transition-shadow">
                <div className="w-16 h-16 bg-[#e8eef5] rounded-full flex items-center justify-center mx-auto mb-4">
                  <value.icon className="w-8 h-8 text-[#1e3a5f]" />
                </div>
                <h3 className="text-xl font-bold text-gray-900 mb-2">{value.title}</h3>
                <p className="text-gray-600 text-sm">{value.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Timeline Section */}
      <section className="py-16 bg-white">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Our Journey</h2>
            <p className="text-gray-600">Key milestones in our growth</p>
          </div>

          <div className="space-y-8">
            {milestones.map((milestone, index) => (
              <div key={index} className="flex gap-6 items-start">
                <div className="flex-shrink-0">
                  <div className="w-20 h-20 bg-[#1e3a5f] rounded-full flex items-center justify-center text-white font-bold text-lg">
                    {milestone.year}
                  </div>
                </div>
                <div className="flex-1 pt-3">
                  <h3 className="text-xl font-bold text-gray-900 mb-2">{milestone.title}</h3>
                  <p className="text-gray-600">{milestone.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Team Section */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Meet Our Team</h2>
            <p className="text-gray-600">The people behind NeighborHelp</p>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            {team.map((member, index) => (
              <div key={index} className="bg-white rounded-xl p-6 text-center">
                <div className="w-24 h-24 bg-gradient-to-br from-[#1e3a5f] to-[#4a7c2c] rounded-full mx-auto mb-4"></div>
                <h3 className="text-xl font-bold text-gray-900 mb-1">{member.name}</h3>
                <p className="text-[#1e3a5f] font-semibold mb-3">{member.role}</p>
                <p className="text-gray-600 text-sm">{member.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 bg-gradient-to-br from-[#1e3a5f] to-[#152d47]">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">Join Our Growing Community</h2>
          <p className="text-lg text-gray-200 mb-8">
            Whether you're looking for services or want to offer your skills, NeighborHelp is the place for you.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link to="/browse-services">
              <button className="px-8 py-4 bg-[#4a7c2c] text-white rounded-lg hover:bg-[#3d6624] cursor-pointer transition-colors text-lg font-semibold">
                Find Services
              </button>
            </Link>
            <Link to="/signup">
              <button className="px-8 py-4 bg-white text-[#1e3a5f] rounded-lg hover:bg-gray-100 cursor-pointer transition-colors text-lg font-semibold">
                Become a Provider
              </button>
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
