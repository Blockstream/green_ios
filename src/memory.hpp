#ifndef GA_SDK_MEMORY_HPP
#define GA_SDK_MEMORY_HPP
#pragma once

#include <sys/mman.h>

#include <array>
#include <memory>
#include <new>
#include <vector>

#include <ga_wally.hpp>

namespace ga {
namespace sdk {

    namespace detail {
        template <typename T> class secure_allocator {
        public:
            using value_type = T;

        private:
            std::allocator<T> m_alloc;

        public:
            secure_allocator() = default;
            secure_allocator(const secure_allocator&) = default;
            secure_allocator(secure_allocator&&) = default;
            secure_allocator& operator=(const secure_allocator&) = delete;
            secure_allocator& operator=(secure_allocator&&) = delete;

            template <typename U>
            secure_allocator(const secure_allocator<U>& other) noexcept
                : m_alloc(other.m_alloc)
            {
            }

            template <typename U> struct rebind {
                using other = secure_allocator<U>;
            };

            T* allocate(size_t n)
            {
                T* ptr = m_alloc.allocate(n);
                const auto ret = mlock(ptr, n);
                if (ret) {
                    m_alloc.deallocate(ptr, n);
                    throw std::bad_alloc();
                }
                return ptr;
            }

            void deallocate(T* ptr, std::size_t n)
            {
                wally::clear(ptr, n);
                munlock(ptr, n);
                m_alloc.deallocate(ptr, n);
            }
        };
    }

    template <typename T> using secure_vector = std::vector<T, detail::secure_allocator<T>>;

    template <typename T, size_t N> class secure_array : private std::array<T, N> {
    private:
        static constexpr auto siz = N * sizeof(T);

    public:
        secure_array()
            : std::array<T, N>()
        {
            const auto ret = mlock(data(), siz);
            if (ret) {
                throw std::bad_alloc();
            }
        }

        ~secure_array()
        {
            wally::clear(data(), siz);
            munlock(data(), siz);
        }

        secure_array(const secure_array& other) = default;
        secure_array(secure_array&& other) = default;
        secure_array& operator=(secure_array& other) = default;
        secure_array& operator=(secure_array&& other) = default;

        using std::array<T, N>::data;
        using std::array<T, N>::size;
        using std::array<T, N>::begin;
        using std::array<T, N>::end;
    };

    // A simple class for slicing constant size containers without copying
    template <typename T> class bytes_view {
    private:
        std::reference_wrapper<const T> bytes;
        std::size_t length;

    public:
        bytes_view(const T& a)
            : bytes(std::cref(a))
            , length(std::extent<T>::value)
        {
        }

        bytes_view(const T& a, size_t len)
            : bytes(std::cref(a))
            , length(len)
        {
        }

        bytes_view(const bytes_view& other) = default;
        bytes_view(bytes_view&& other) = default;
        bytes_view& operator=(bytes_view& other) = default;
        bytes_view& operator=(bytes_view&& other) = default;

        const unsigned char* data() const { return data(std::is_class<T>()); }
        constexpr size_t size() const { return length; }
        const unsigned char* end() const { return data() + size(); }

    private:
        const unsigned char* data(std::true_type) const { return bytes.get().data(); }
        const unsigned char* data(std::false_type) const { return wally::detail::get_p(bytes); }
    };

    template <typename T> inline const bytes_view<T> make_bytes_view(const T& v) { return bytes_view<T>(v); }
    template <typename T> inline const bytes_view<T> make_bytes_view(const T& v, size_t n)
    {
        return bytes_view<T>(v, n);
    }

    // A class representing a null range of bytes
    class nullbytes {
    public:
        nullbytes() = default;
        nullbytes(const nullbytes& other) = default;
        nullbytes(nullbytes&& other) = default;
        nullbytes& operator=(const nullbytes& other) = delete;
        nullbytes& operator=(nullbytes&& other) noexcept = delete;

        const unsigned char* data() const { return nullptr; }
        size_t size() const { return 0; }
    };

    template <typename T, typename T1, typename T2> inline void init_container(T& dst, const T1& arg1, const T2& arg2)
    {
        GA_SDK_RUNTIME_ASSERT(dst.size() == arg1.size() + arg2.size()); // No partial fills supported
        std::copy(arg1.data(), arg1.end(), dst.data());
        std::copy(arg2.data(), arg2.end(), dst.data() + arg1.size());
    }
}
}

#endif
