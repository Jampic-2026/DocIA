import { motion } from 'framer-motion';

type AnimatedWrapperProps = {
  children: React.ReactNode;
  delay?: number;
  className?: string;
};

export default function AnimatedWrapper({ children, delay = 0, className }: AnimatedWrapperProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.55, delay }}
      className={className}
    >
      {children}
    </motion.div>
  );
}
