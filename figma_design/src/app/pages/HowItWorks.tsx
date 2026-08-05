import { Search, MessageSquare, CheckCircle2, UserPlus, FileText, Shield, CreditCard, Star, Bell } from 'lucide-react';
import { Link } from 'react-router';

export default function HowItWorksPage() {
  const steps = [
    {
      icon: UserPlus,
      title: '1. Create Your Account',
      description: 'Sign up for free and complete your profile in minutes. Tell us about your needs and preferences.'
    },
    {
      icon: Search,
      title: '2. Post Your Request',
      description: 'Describe the service you need with details about timing, location, and budget. The more specific, the better!'
    },
    {
      icon: MessageSquare,
      title: '3. Review Proposals',
      description: 'Receive proposals from qualified providers. Compare their profiles, reviews, and pricing.'
    },
    {
      icon: CheckCircle2,
      title: '4. Hire & Pay Securely',
      description: 'Choose the best provider and pay securely through our platform. Your payment is protected.'
    },
    {
      icon: Star,
      title: '5. Leave a Review',
      description: 'After the service is complete, share your experience to help the community make informed decisions.'
    }
  ];

  const features = [
    {
      icon: Shield,
      title: 'Verified Providers',
      description: 'All service providers go through our verification process including background checks and credential verification.'
    },
    {
      icon: CreditCard,
      title: 'Secure Payments',
      description: 'Your payment is held securely and only released when you confirm the job is done to your satisfaction.'
    },
    {
      icon: Star,
      title: 'Trusted Reviews',
      description: 'Read authentic reviews from real customers in your community who have used the services.'
    },
    {
      icon: Bell,
      title: 'Real-time Updates',
      description: 'Stay informed with instant notifications about proposals, messages, and service updates.'
    }
  ];

  const faqs = [
    {
      question: 'Is NeighborHelp free to use?',
      answer: 'Yes! Creating an account and posting service requests is completely free. We only charge a small service fee when you successfully hire a provider through our platform.'
    },
    {
      question: 'How are providers vetted?',
      answer: 'All providers must pass our verification process, which includes identity verification, background checks, and credential verification for licensed services.'
    },
    {
      question: 'What if I\'m not satisfied with the service?',
      answer: 'We have a satisfaction guarantee. If you\'re not satisfied, contact our support team within 48 hours, and we\'ll work to resolve the issue or provide a refund.'
    },
    {
      question: 'How does payment work?',
      answer: 'Payment is made securely through our platform. Your funds are held in escrow and only released to the provider once you confirm the work is complete.'
    }
  ];

  return (
    <>
      {/* Hero Section */}
      <section className="bg-gradient-to-br from-[#e8eef5] to-white py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h1 className="text-5xl font-bold text-gray-900 mb-4">How NeighborHelp Works</h1>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            Getting the help you need is simple. Follow these easy steps to connect with trusted service providers in your community.
          </p>
        </div>
      </section>

      {/* Steps Section */}
      <section className="py-16 bg-white">
        <div className="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="space-y-12">
            {steps.map((step, index) => (
              <div key={index} className="flex gap-6 items-start">
                <div className="flex-shrink-0">
                  <div className="w-16 h-16 bg-[#1e3a5f] rounded-full flex items-center justify-center">
                    <step.icon className="w-8 h-8 text-white" />
                  </div>
                </div>
                <div className="flex-1">
                  <h3 className="text-2xl font-bold text-gray-900 mb-2">{step.title}</h3>
                  <p className="text-lg text-gray-600">{step.description}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-16 bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Why Choose NeighborHelp?</h2>
            <p className="text-gray-600">Trust and safety are our top priorities</p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
            {features.map((feature, index) => (
              <div key={index} className="bg-white rounded-xl p-6 shadow-sm hover:shadow-md transition-shadow">
                <div className="w-12 h-12 bg-[#e8eef5] rounded-lg flex items-center justify-center mb-4">
                  <feature.icon className="w-6 h-6 text-[#1e3a5f]" />
                </div>
                <h3 className="text-lg font-bold text-gray-900 mb-2">{feature.title}</h3>
                <p className="text-gray-600 text-sm">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* FAQ Section */}
      <section className="py-16 bg-white">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-12">
            <h2 className="text-3xl font-bold text-gray-900 mb-3">Frequently Asked Questions</h2>
            <p className="text-gray-600">Got questions? We've got answers.</p>
          </div>

          <div className="space-y-6">
            {faqs.map((faq, index) => (
              <div key={index} className="bg-gray-50 rounded-xl p-6">
                <h3 className="text-lg font-bold text-gray-900 mb-2">{faq.question}</h3>
                <p className="text-gray-600">{faq.answer}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-16 bg-gradient-to-br from-[#1e3a5f] to-[#152d47]">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold text-white mb-4">Ready to Get Started?</h2>
          <p className="text-lg text-gray-200 mb-8">
            Join thousands of satisfied customers who found the perfect service provider on NeighborHelp.
          </p>
          <Link to="/signup">
            <button className="px-8 py-4 bg-[#4a7c2c] text-white rounded-lg hover:bg-[#3d6624] cursor-pointer transition-colors text-lg font-semibold">
              Post Your First Request
            </button>
          </Link>
        </div>
      </section>
    </>
  );
}
