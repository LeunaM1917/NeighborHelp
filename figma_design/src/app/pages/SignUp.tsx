import { Briefcase, Wrench, ArrowRight } from 'lucide-react';
import { Link, useNavigate } from 'react-router';
import { ImageWithFallback } from '../components/figma/ImageWithFallback';

export default function SignUpPage() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Simple Header */}
      <header className="py-6 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <Link to="/" className="flex items-center gap-3 w-fit">
            <ImageWithFallback
              src="../../imports/689227648_809030255334603_3730778276829339656_n-removebg-preview-1.png"
              alt="NeighborHelp"
              className="h-12 w-auto"
            />
            <span className="font-bold text-xl">
              <span className="text-[#1e3a5f]">Neighbor</span>
              <span className="text-[#4a7c2c]">Help</span>
            </span>
          </Link>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex items-center justify-center px-4 sm:px-6 lg:px-8 py-12">
        <div className="max-w-4xl w-full">
          <div className="text-center mb-12">
            <h1 className="text-5xl font-bold text-gray-900 mb-4">Welcome to NeighborHelp</h1>
            <p className="text-xl text-gray-600">Which describes you best?</p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 max-w-3xl mx-auto">
            {/* Customer Card */}
            <button
              onClick={() => navigate('/signup/customer')}
              className="group bg-white rounded-2xl p-8 border-2 border-gray-200 hover:border-[#1e3a5f] hover:shadow-xl transition-all cursor-pointer"
            >
              <div className="bg-gradient-to-br from-[#e8f4e0] to-[#c8e6b8] rounded-2xl p-12 mb-6 group-hover:scale-105 transition-transform">
                <Briefcase className="w-20 h-20 text-[#1e3a5f] mx-auto" />
              </div>
              <div className="flex items-center justify-center gap-2 mb-3">
                <h2 className="text-2xl font-bold text-gray-900">Customer</h2>
                <ArrowRight className="w-6 h-6 text-gray-900 group-hover:translate-x-1 transition-transform" />
              </div>
              <p className="text-gray-600">Post requests and hire services</p>
            </button>

            {/* Service Provider Card */}
            <button
              onClick={() => navigate('/signup/provider')}
              className="group bg-white rounded-2xl p-8 border-2 border-gray-200 hover:border-[#4a7c2c] hover:shadow-xl transition-all cursor-pointer"
            >
              <div className="bg-gradient-to-br from-[#e8f4e0] to-[#b8d89f] rounded-2xl p-12 mb-6 group-hover:scale-105 transition-transform">
                <Wrench className="w-20 h-20 text-[#4a7c2c] mx-auto" />
              </div>
              <div className="flex items-center justify-center gap-2 mb-3">
                <h2 className="text-2xl font-bold text-gray-900">Service Provider</h2>
                <ArrowRight className="w-6 h-6 text-gray-900 group-hover:translate-x-1 transition-transform" />
              </div>
              <p className="text-gray-600">Offer services and get paid</p>
            </button>
          </div>

          <div className="text-center mt-12">
            <p className="text-gray-600">
              Already have an account?{' '}
              <Link to="/login" className="text-[#1e3a5f] font-semibold hover:underline cursor-pointer">
                Log in
              </Link>
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}
